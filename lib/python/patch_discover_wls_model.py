"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

Post-processing script for WebLogic Deploy Tooling (WDT) discovery output.

This script updates the discovered WDT model JSON file by adding the following
fields required for WebLogic migration to OCI:

1. AdminConsolePort
   - Added only under topology.Server.<AdminServerName>

2. DomainPath
   - Appended as the final entry in the topology section

3. OraclePath
   - Appended immediately after DomainPath

DomainPath and OraclePath are loaded from the provided on-prem.env file,
using keys:
    domain_home=<path>
    oracle_home=<path>

AdminConsolePort is dynamically determined from on-prem WebLogic config.xml
using the following priority:

  1. If <administration-port-enabled>true</administration-port-enabled>:
     - server-level in admin server block <administration-port>
     - domain-level <administration-port>
     - else DEFAULT_ADMINISTRATION_PORT (9002)

  2. If SSL is enabled on AdminServer:
     - <network-access-point name="SecuredExternAdmin"><listen-port>
     - <ssl><listen-port>

  3. From server-start arguments:
       -Dweblogic.management.server=host:port

  4. <network-access-point name="ExternAdmin"><listen-port>

  5. Fallback:
     <listen-port>

AdminServer is determined strictly from:
    topology.AdminServerName

Usage:
    patch_discover_wls_model.py <model.json> <on-prem.env>
"""

import json
import os
import re
import sys

DEFAULT_ADMINISTRATION_PORT = 9002

# ---------------------------------------------------------
# ENV loader
# ---------------------------------------------------------
def load_env_var(file_path, key):
    if not os.path.exists(file_path):
        return None

    pattern = re.compile(
        r'^\s*(?:export\s+)?' + re.escape(key) + r'\s*=\s*(.+?)\s*$',
        re.IGNORECASE,
        )

    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            m = pattern.match(stripped)
            if m:
                return m.group(1).strip()

    return None


def load_paths_from_env(env_file):
    domain_home = load_env_var(env_file, "domain_home")
    oracle_home = load_env_var(env_file, "oracle_home")

    if not domain_home or not oracle_home:
        print("ERROR: domain_home or oracle_home missing in on-prem.env", file=sys.stderr)
        return None, None

    return domain_home, oracle_home


# ---------------------------------------------------------
# Admin port logic
# ---------------------------------------------------------
def get_admin_port_from_model(model, admin_server_name):

    topology = model.get("topology", {})
    servers = topology.get("Server", {})

    admin_server = servers.get(admin_server_name)
    if not admin_server:
        print(f"ERROR: AdminServer '{admin_server_name}' not found in model", file=sys.stderr)
        return None

    admin_port_enabled = topology.get("AdministrationPortEnabled", False)

    # ------------------------------------------------------------------
    # 1 — Administration Port Enabled
    # ------------------------------------------------------------------
    if admin_port_enabled:

        # 1a — server-level
        port = admin_server.get("AdministrationPort")
        if port:
            return str(port)

        # 1b — domain-level
        port = topology.get("AdministrationPort")
        if port:
            return str(port)

        # 1c — default
        return str(DEFAULT_ADMINISTRATION_PORT)

    # ------------------------------------------------------------------
    # 2 — SSL enabled
    # ------------------------------------------------------------------
    ssl = admin_server.get("SSL")
    if ssl:

        # 2a — NAP "SecuredExternAdmin"
        naps = admin_server.get("NetworkAccessPoint", {})
        if naps:
            sec = naps.get("SecuredExternAdmin", {})
            port = sec.get("ListenPort")
            if port:
                return str(port)

        # 2b — SSL.ListenPort
        port = ssl.get("ListenPort")
        if port:
            return str(port)

    # ------------------------------------------------------------------
    # 3 — ServerStart Arguments
    # ------------------------------------------------------------------
    ss = admin_server.get("ServerStart")
    if ss:
        args = ss.get("Arguments", "")
        m = re.search(r"-Dweblogic\.management\.server=.*?:(\d+)", args)
        if m:
            return m.group(1)

    # ------------------------------------------------------------------
    # 4 — NAP "ExternAdmin"
    # ------------------------------------------------------------------
    naps = admin_server.get("NetworkAccessPoint", {})
    if naps:
        ext = naps.get("ExternAdmin", {})
        port = ext.get("ListenPort")
        if port:
            return str(port)

    # ------------------------------------------------------------------
    # 5 — fallback ListenPort
    # ------------------------------------------------------------------
    port = admin_server.get("ListenPort")
    if port:
        return str(port)

    return None


# ---------------------------------------------------------
# Patch model JSON
# ---------------------------------------------------------
def patch_model(json_file, env_file):

    domain_home, oracle_home = load_paths_from_env(env_file)
    if not domain_home or not oracle_home:
        return 1

    # Load model JSON
    try:
        with open(json_file, "r", encoding="utf-8") as f:
            model = json.load(f)
    except Exception as e:
        print(f"ERROR: Failed to load JSON: {e}", file=sys.stderr)
        return 1

    topology = model.setdefault("topology", {})
    servers = topology.get("Server", {})

    # Insert DomainPath + OraclePath
    topology["DomainPath"] = domain_home
    topology["OraclePath"] = oracle_home

    # Ensure AdminServerName exists
    admin_server_name = topology.get("AdminServerName")
    if not admin_server_name:
        print("ERROR: topology.AdminServerName missing", file=sys.stderr)
        return 1

    if admin_server_name not in servers:
        print(f"ERROR: AdminServerName '{admin_server_name}' not found under topology.Server",
              file=sys.stderr)
        return 1

    # Retrieve AdminConsolePort
    port = get_admin_port_from_model(model, admin_server_name)
    if not port:
        print("ERROR: Unable to determine AdminConsolePort from model", file=sys.stderr)
        return 1

    servers[admin_server_name]["AdminConsolePort"] = port
    print(f"INFO: AdminConsolePort = {port}")

    # Write JSON back to disk
    try:
        with open(json_file, "w", encoding="utf-8") as f:
            json.dump(model, f, indent=4)
    except Exception as e:
        print(f"ERROR: Failed writing JSON: {e}", file=sys.stderr)
        return 1

    print("SUCCESS: Updated model saved to", json_file)
    return 0


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: patch_discover_wls_model.py <model.json> <on-prem.env>")
        sys.exit(1)

    sys.exit(patch_model(sys.argv[1], sys.argv[2]))