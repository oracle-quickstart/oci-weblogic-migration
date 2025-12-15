"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

This script enriches a WDT discover model JSON with infrastructure
details collected from each WebLogic machine via SSH. It populates:

   - OS details
   - NodeManager & WebLogic server JVM arguments
   - Canonical JAVA_HOME path on each host
   - Owner (oracle user) UID/GID
   - Extra OS Paths referenced by deployments (filtered per host)
"""

import json
import subprocess
import argparse
import os

from patch_discover_wls_model import load_env_var

parser = argparse.ArgumentParser(
    description="Enrich WDT discover JSON with infrastructure details and host-specific Java home paths."
)
parser.add_argument("--input_model", required=True, help="Path to input discovered.json")
parser.add_argument("--output_model", required=True, help="Path to output enriched JSON model")
parser.add_argument("--env_file", required=True, help="Environment variable file to load SSH and domain parameters")
args = parser.parse_args()

env_file = args.env_file

# =====================================================================
# LOAD ENVIRONMENT VARIABLES
# =====================================================================
SSH_USER = load_env_var(env_file, "ssh_user")
SSH_PRIVATE_KEY = load_env_var(env_file, "ssh_private_key_file")
SSH_PRIVATE_KEY_PASS = load_env_var(env_file, "ssh_private_key_pass_file")
SSH_PASSWORD_FILE = load_env_var(env_file, "ssh_password_file")

DOMAIN_HOME = load_env_var(env_file, "domain_home")
JAVA_HOME = load_env_var(env_file, "java_home")
ORACLE_HOME = load_env_var(env_file, "oracle_home")

# =====================================================================
# SSH HELPER FUNCTIONS
# =====================================================================
def run_ssh(host, cmd):
    """
    Execute a command via SSH on a remote WebLogic host.

    Supports:
      - Password auth if sshpass is configured
      - Private key authentication
      - Disabled strict host key checking

    Returns stdout or an empty string on error.
    """
    base_cmd = ["ssh", "-o", "StrictHostKeyChecking=no"]
    if SSH_PRIVATE_KEY:
        base_cmd += ["-i", SSH_PRIVATE_KEY]

    target = "%s@%s" % (SSH_USER, host)
    full_cmd = base_cmd + [target, cmd]

    if SSH_PASSWORD_FILE and os.path.exists(SSH_PASSWORD_FILE):
        full_cmd = ["sshpass", "-f", SSH_PASSWORD_FILE] + full_cmd

    proc = subprocess.Popen(
        full_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True
    )
    out, err = proc.communicate()

    if proc.returncode != 0:
        print(f"[WARN] SSH failed {host}: {err.strip()}")
        return ""

    return out.strip()


def remote_path_exists(host, path):
    """
    Check if a given absolute path exists on a specific host.

    Returns True/False based on remote test command.
    """
    if not path:
        return False
    cmd = f"[ -e '{path}' ] && echo YES || echo NO"
    out = run_ssh(host, cmd).strip()
    return out == "YES"

# =====================================================================
# JAVA HOME DETECTION
# =====================================================================
def detect_canonical_java_home(host):
    """
    Detect the real JAVA_HOME on a host by following the actual 'java'
    symlink chain (using readlink -f).

    Falls back to the configured JAVA_HOME if remote detection fails.
    """
    cmd = "readlink -f $(which java) 2>/dev/null"
    java_bin = run_ssh(host, cmd)

    if not java_bin:
        return JAVA_HOME

    if java_bin.endswith("/bin/java"):
        return java_bin[:-9]

    cmd2 = f"dirname $(dirname {java_bin})"
    path = run_ssh(host, cmd2)
    return path or JAVA_HOME

# =====================================================================
# OS DETAILS
# =====================================================================
def get_os_details(host):
    """
    Collect OS metadata from a Linux host:

    - Reads VERSION_ID from /etc/os-release (preferred)
    - Falls back to parsing /etc/redhat-release
    - Extracts only the MAJOR version (e.g. 8 from 8.8)
    - Uses uname for kernel/architecture/OS name

    This produces correct OS_RELEASE and OS_VERSION values (e.g. "8")
    instead of "Linux" like InfraDiscoverer.
    """
    # uname basics
    osname = run_ssh(host, "uname -s") or "unknown"
    arch = run_ssh(host, "uname -m") or "unknown"
    kernel = run_ssh(host, "uname -r") or "unknown"

    # Read VERSION_ID from /etc/os-release or fallback
    release_cmd = (
        # VERSION_ID="8.9"
        "source /etc/os-release 2>/dev/null && echo ${VERSION_ID} || "
        # Fallback for Oracle/RHEL/CentOS format: "Red Hat Enterprise Linux release 8.6"
        "cat /etc/redhat-release 2>/dev/null | grep -oE '[0-9]+(\\.[0-9]+)?' | head -1 || "
        "echo ''"
    )

    release_full = run_ssh(host, release_cmd).strip()

    # Extract major version
    major = ""

    if release_full:
        major = release_full.split('.')[0]
        # ensure it's numeric
        if not major.isdigit():
            import re
            m = re.search(r'\d+', release_full)
            major = m.group(0) if m else ""

    # Final fallback
    if not major:
        major = "8"

    return {
        "OS_RELEASE": major,
        "OS_VERSION": major,
        "Hostname": host,
        "Arch": arch,
        "OS": osname.lower(),
        "Kernel": kernel
    }

# =====================================================================
# NODE MANAGER AND SERVER JVM EXTRACTION
# =====================================================================
def get_node_manager_args(host):
    """Return JVM arguments used by NodeManager on a host."""
    cmd = "ps -ef | grep '[j]ava.*NodeManager'"
    out = run_ssh(host, cmd)
    return [out] if out else []

def get_weblogic_servers(host):
    """
    Extract the JVM startup arguments of WebLogic Server processes.

    AdminServer is always sorted first.
    """
    cmd = "ps -ef | grep '[j]ava.*weblogic.Server'"
    out = run_ssh(host, cmd)
    if not out:
        return []

    servers = []
    for line in out.splitlines():
        p = line.split()
        servers.append(" ".join(p[7:]))

    return sorted(servers, key=lambda x: 0 if "AdminServer" in x else 1)

# =====================================================================
# ORACLE USER DETAILS
# =====================================================================

def get_owner_details(host):
    """Return UID/GID information for the 'oracle' user."""
    uid = run_ssh(host, "id -u oracle") or "1001"
    gid = run_ssh(host, "id -g oracle") or "1001"
    return {"uid": uid, "uname": "oracle", "gid": gid, "gname": "oracle"}

# =====================================================================
# EXTRA OS PATH DISCOVERY
# =====================================================================
TOKEN_MAP = {
    "@@ORACLE_HOME@@": ORACLE_HOME,
    "@@DOMAIN_HOME@@": DOMAIN_HOME,
    "@@JAVA_HOME@@": JAVA_HOME,
}

def resolve_tokens(path):
    """Replace WDT tokens in a path with actual values."""
    for token, value in TOKEN_MAP.items():
        if token in path:
            path = path.replace(token, value)
    return path


def get_extra_os_paths(machine_name, data):
    """
    Identify “extra” directories referenced by deployments or keystores
    which are not under ORACLE_HOME / DOMAIN_HOME / JAVA_HOME .

    These paths may or may not exist on each machine. They will be
    validated later using SSH.
    """
    extra_dirs = []

    ORACLE_HOME = resolve_tokens("@@ORACLE_HOME@@")
    DOMAIN_HOME = resolve_tokens("@@DOMAIN_HOME@@")
    JAVA_HOME   = resolve_tokens("@@JAVA_HOME@@")

    def is_custom_dir(path):
        if not path:
            return False, ""

        original = path

        # ignore token-only values
        SKIP_TOKENS = [
            "@@ORACLE_HOME@@", "@@DOMAIN_HOME@@",
            "@@JAVA_HOME@@", "@@PWD@@", "@@TMP@@"
        ]
        for tok in SKIP_TOKENS:
            if original.startswith(tok):
                return False, ""

        path = resolve_tokens(path)

        if not os.path.isabs(path):
            return False, ""

        parent = os.path.dirname(path)
        return True, parent

    def add_if_custom(path):
        ok, d = is_custom_dir(path)
        if ok and d:
            extra_dirs.append(d)

    # ---- scan application and library deployments ----
    apps = data.get("appDeployments", {})
    for deploy_type in ["Library", "Application"]:
        deployments = apps.get(deploy_type, {})
        for name, deploy in deployments.items():
            add_if_custom(deploy.get("SourcePath"))

            plan_dir  = deploy.get("PlanDir")
            plan_path = deploy.get("PlanPath")

            if plan_path:
                full_path = os.path.join(resolve_tokens(plan_dir), resolve_tokens(plan_path)) if plan_dir else resolve_tokens(plan_path)
                add_if_custom(full_path)

    # ---- scan keystore and SSL paths ----
    servers = data.get("topology", {}).get("Server", {})
    for server_name, s in servers.items():
        if s.get("Machine") != machine_name:
            continue

        add_if_custom(s.get("CustomIdentityKeyStoreFileName"))
        add_if_custom(s.get("CustomTrustKeyStoreFileName"))
        ssl = s.get("SSL", {})
        add_if_custom(ssl.get("TrustedCAFileName"))

    # ---- JVM arguments ----
    machine_res = data.get("resources", {}).get("Machines", {}).get(machine_name, {})
    all_jvms = []
    all_jvms.extend(machine_res.get("NodeManager", []))
    all_jvms.extend(machine_res.get("WeblogicServer", []))

    exclude = set([
        ORACLE_HOME.rstrip("/"),
        DOMAIN_HOME.rstrip("/"),
        JAVA_HOME.rstrip("/"),
    ])

    JVM_PREFIXES = ["-Djava.io.tmpdir=", "-Duser.dir="]

    for jvm_cmd in all_jvms:
        for arg in jvm_cmd.split():
            for prefix in JVM_PREFIXES:
                if arg.startswith(prefix):
                    p = resolve_tokens(arg[len(prefix):])
                    parent = os.path.dirname(p)
                    if parent not in exclude:
                        extra_dirs.append(parent)

    return sorted(set(extra_dirs))

# =====================================================================
# LOAD INPUT JSON
# =====================================================================
with open(args.input_model) as f:
    data = json.load(f)

# =====================================================================
# DETECT MACHINES
# =====================================================================
machines = []
topo = data.get("topology", {}).get("Machine", {})

for mname, mobj in topo.items():
    host = mobj.get("NodeManager", {}).get("ListenAddress")
    if host:
        machines.append({"name": mname, "host": host})

# =====================================================================
# ENSURE resources→Machines EXISTS
# =====================================================================
if "resources" not in data:
    data["resources"] = {}
if "Machines" not in data["resources"]:
    data["resources"]["Machines"] = {}

resources_machines = data["resources"]["Machines"]

# =====================================================================
# COLLECT AND ENRICH DATA PER MACHINE
# =====================================================================
for m in machines:
    name = m["name"]
    host = m["host"]

    print(f"[INFO] Fetching from host {host} ...")

    os_details = get_os_details(host)
    owner = get_owner_details(host)
    nodemgr = get_node_manager_args(host)
    wls = get_weblogic_servers(host)

    raw_extra_paths = get_extra_os_paths(name, data)

    # Validate paths for EACH HOST
    extra_paths = []
    for p in raw_extra_paths:
        if remote_path_exists(host, p):
            extra_paths.append(p)
        else:
            print(f"[INFO] Skipping non-existent path on {host}: {p}")

    canonical_java = detect_canonical_java_home(host)

    resources_machines[name] = {
        "DETAILS": os_details,
        "Owner": owner,
        "NodeManager": nodemgr,
        "WeblogicServer": wls,
        "JavaPath": JAVA_HOME,
        "CanonicalJavaPath": canonical_java,
        "ExtraOSPaths": extra_paths,
    }

# =====================================================================
# SAVE OUTPUT JSON
# =====================================================================
with open(args.output_model, "w") as f:
    json.dump(data, f, indent=4)

print(f"[INFO] Infra enrichment written to {args.output_model}")