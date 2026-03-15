#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Multi-node WLS migration archiver (Python 3, no WDT/WLST imports)

Behavior (UPDATED)
------------------
Per host:
  0) SSH precheck
  1) Estimate largest archive input size for that host (remote du-based).
  2) If admin does NOT have enough space to receive the largest tar for that host:
       - Create ALL tars on that host in /tmp (tar-by-tar, with /tmp space checks)
       - Do NOT SCP or upload anything for that host
       - Leave all tars in /tmp on that host
       - Print WARNING with admin free/required info
       - Print TODO with manual scp + OCI put commands (OCI CLI only on admin)
  3) Else (admin has enough for largest):
       For each archive type:
         tar on remote -> scp to admin out -> (optional) oci put -> cleanup remote+local -> next

Output format
-------------
WARNING Messages:
        N. WLSDPLY-.....
TODO Messages:
        N. WLSDPLY-.....
Tar TODO format matches the intended "cd / && tar ..." style.

Logging
-------
All command outputs and INFO messages are appended to:
  tool_home/logs/migration_script.log

Security note
-------------
Archives may contain sensitive data (keystores, configs). Handle per Oracle/customer security & compliance.

Notes / fixes included in this version
--------------------------------------
- FIX: MessageCollector methods properly indented (no accidental top-level def / nested methods)
- FIX: log_info() safely handles log_file=None
- IMPROVE: ensure_bucket() includes --namespace-name for "bucket get" (common OCI CLI requirement)
  (Verify your OCI CLI version/standards; some environments require additional flags/policies.)
"""
import argparse
import json
import shlex
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any

EXCLUDES = [
    ".pid",
    ".state",
    ".core",
    "diag/ofm/*/*/lck/*.lck",
    "servers/*/logs/*.*",
    "*.log*[0-9]",
    "*.log",
    "*.out",
    "*.out*[0-9]",
    "*.out",
    "servers/*/data/store/diagnostics/*",
    "oracle-dfw-*/sampling/jvm_threads*",
]

ARCHIVE_ORDER = ["java_home", "domain_home", "weblogic_home", "custom_dirs"]
REMOTE_SPACE_HEADROOM = 1.20
ADMIN_SPACE_HEADROOM = 1.10
MIN_FREE_BYTES_FLOOR = 200 * 1024 * 1024  # 200MB slack


def log_info(msg: str, log_file: Optional[str]) -> None:
    """Append a timestamped INFO entry to the log file (UTC). If log_file is None, do nothing."""
    if not log_file:
        return
    ts = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    Path(log_file).parent.mkdir(parents=True, exist_ok=True)
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"{ts} [INFO] {msg}\n")


def _redact_cmd(cmd: List[str]) -> List[str]:
    """Redact sensitive values from a command list before logging (currently: ssh key after -i)."""
    redacted: List[str] = []
    i = 0
    while i < len(cmd):
        if cmd[i] == "-i" and i + 1 < len(cmd):
            redacted.extend(["-i", "<REDACTED_SSH_KEY>"])
            i += 2
            continue
        redacted.append(cmd[i])
        i += 1
    return redacted


def fmt_bytes(n: int) -> str:
    """Convert bytes to a human-readable base-1024 string."""
    if n < 1024:
        return f"{n}B"
    f = float(n)
    for unit in ["KB", "MB", "GB", "TB", "PB"]:
        f = f / 1024.0
        if f < 1024.0:
            return f"{f:.1f}{unit}"
    return f"{f:.1f}EB"


def run_local(cmd: List[str], log_file: Optional[str] = None) -> Tuple[int, str]:
    """
    Run a local command and optionally append redacted command + combined output to log_file.
    Captures stdout+stderr (merged).
    """
    kwargs: Dict[str, Any] = dict(stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if sys.version_info >= (3, 7):
        kwargs["text"] = True
    else:
        kwargs["universal_newlines"] = True
    p = subprocess.run(cmd, **kwargs)
    out = p.stdout or ""
    if log_file:
        Path(log_file).parent.mkdir(parents=True, exist_ok=True)
        with open(log_file, "a", encoding="utf-8") as f:
            safe_cmd = _redact_cmd(cmd)
            f.write(f"$ {' '.join(shlex.quote(c) for c in safe_cmd)}\n")
            if out:
                f.write(out)
                if not out.endswith("\n"):
                    f.write("\n")
    return p.returncode, out


def run_ssh(
        user: str,
        host: str,
        key: str,
        port: int,
        remote_cmd: str,
        timeout: int,
        log_file: Optional[str] = None
) -> Tuple[int, str]:
    """Execute a remote command over SSH and return (rc, combined_output)."""
    cmd = [
        "ssh", "-i", key, "-p", str(port),
        "-o", "BatchMode=yes",
        "-o", f"ConnectTimeout={timeout}",
        "-o", "StrictHostKeyChecking=accept-new",
        f"{user}@{host}",
        remote_cmd,
    ]
    return run_local(cmd, log_file=log_file)


def scp_get(
        user: str,
        host: str,
        key: str,
        port: int,
        remote_file: str,
        local_dir: str,
        timeout: int,
        log_file: Optional[str] = None
) -> Tuple[int, str]:
    """Copy a file from remote host to local_dir using scp."""
    Path(local_dir).mkdir(parents=True, exist_ok=True)
    cmd = [
        "scp", "-i", key, "-P", str(port),
        "-o", "BatchMode=yes",
        "-o", f"ConnectTimeout={timeout}",
        "-o", "StrictHostKeyChecking=accept-new",
        f"{user}@{host}:{remote_file}",
        local_dir,
    ]
    return run_local(cmd, log_file=log_file)


def load_env_from_on_prem_env(on_prem_env_path: str) -> Dict[str, str]:
    """Load key=value pairs from on-prem.env (no shell execution)."""
    p = Path(on_prem_env_path)
    if not p.is_file():
        raise RuntimeError(f"Env file not found: {on_prem_env_path}")
    env: Dict[str, str] = {}
    for raw in p.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip()
    return env


def require(env: Dict[str, str], key: str, where: str) -> str:
    """Fetch required non-empty config value."""
    val = env.get(key)
    if not val:
        raise ValueError(f"Missing required '{key}' in {where}")
    return val


def build_plan_from_wlsdomain(wlsdomain: dict) -> Tuple[str, List[dict]]:
    """Build (domain_name, nodes[]) from wlsdomain JSON."""
    topo = wlsdomain.get("topology", {}) or {}
    domain_name = topo.get("Name")
    domain_home = (topo.get("DomainPath") or "").rstrip("/")
    oracle_home = (topo.get("OraclePath") or "").rstrip("/")
    if not domain_name or not domain_home or not oracle_home:
        raise ValueError("wlsdomain.json missing topology.Name and/or topology.DomainPath and/or topology.OraclePath")

    machines = (wlsdomain.get("resources", {}) or {}).get("Machines", {}) or {}
    if not machines:
        raise ValueError("wlsdomain.json missing resources.Machines")

    nodes: List[dict] = []
    for machine, m in machines.items():
        m = m or {}
        details = (m.get("DETAILS") or {})
        host = details.get("Hostname")
        if not host:
            raise ValueError(f"resources.Machines.{machine}.DETAILS.Hostname missing")

        java_home = (m.get("CanonicalJavaPath") or m.get("JavaPath") or "").rstrip("/")
        if not java_home:
            raise ValueError(f"resources.Machines.{machine}.CanonicalJavaPath/JavaPath missing")

        custom_dirs = m.get("ExtraOSPaths", []) or []
        custom_dirs = [p.rstrip("/") for p in custom_dirs if isinstance(p, str) and p.strip()]

        nodes.append({
            "machine": machine,
            "host": host,
            "java_home": java_home,
            "domain_home": domain_home,
            "weblogic_home": oracle_home,
            "custom_dirs": custom_dirs,
        })

    nodes.sort(key=lambda x: (x["machine"], x["host"]))
    return domain_name, nodes


def admin_free_bytes(path: str) -> int:
    """Free bytes on admin filesystem containing path."""
    Path(path).mkdir(parents=True, exist_ok=True)
    return shutil.disk_usage(path).free


def remote_free_bytes(
        user: str,
        host: str,
        key: str,
        port: int,
        timeout: int,
        mount_path: str,
        log_file: Optional[str]
) -> int:
    """Free bytes on remote filesystem containing mount_path."""
    cmd = f"df -B1 {shlex.quote(mount_path)} | tail -1 | awk '{{print $4}}'"
    rc, out = run_ssh(user, host, key, port, cmd, timeout, log_file=log_file)
    if rc != 0 or not out.strip().isdigit():
        raise RuntimeError(f"Failed to read free space for {mount_path}: {out.strip()}")
    return int(out.strip())


def remote_du_bytes(
        user: str,
        host: str,
        key: str,
        port: int,
        timeout: int,
        paths: List[str],
        log_file: Optional[str]
) -> int:
    """Estimate total bytes of remote paths using du; tries -sb then -sk."""
    if not paths:
        return 0
    quoted = " ".join(shlex.quote(p) for p in paths)

    cmd_sb = f"du -sb {quoted} 2>/dev/null | awk '{{s+=$1}} END{{print s+0}}'"
    rc, out = run_ssh(user, host, key, port, cmd_sb, timeout, log_file=log_file)
    if rc == 0 and out.strip().isdigit():
        return int(out.strip())

    cmd_sk = f"du -sk {quoted} 2>/dev/null | awk '{{s+=$1}} END{{print s+0}}'"
    rc, out = run_ssh(user, host, key, port, cmd_sk, timeout, log_file=log_file)
    if rc != 0 or not out.strip().isdigit():
        raise RuntimeError(f"Failed to estimate size with du: {out.strip()}")
    return int(out.strip()) * 1024


def excludes_flags_todo() -> str:
    """Tar --exclude flags for TODO strings (single-quoted patterns)."""
    return " ".join([f"--exclude='{p}'" for p in EXCLUDES])


def excludes_flags_remote() -> str:
    """Tar --exclude flags for remote commands (shell-escaped patterns)."""
    return " ".join([f"--exclude={shlex.quote(p)}" for p in EXCLUDES])


def tar_one_dir_cmd(src_dir: str, out_file: str) -> str:
    """Remote command to create tar.gz of a single absolute directory, stored relative to /."""
    src_dir = src_dir.rstrip("/")
    if not src_dir.startswith("/"):
        raise ValueError(f"Expected absolute path, got: {src_dir}")
    rel = src_dir.lstrip("/")
    return (
        "set -e; "
        f"test -d {shlex.quote(src_dir)}; "
        "cd /; "
        f"/usr/bin/tar czf {shlex.quote(out_file)} "
        f"{excludes_flags_remote()} "
        f"{shlex.quote(rel)}"
    )


def tar_many_dirs_cmd(src_dirs: List[str], out_file: str) -> str:
    """Remote command to create tar.gz of multiple absolute paths, stored relative to /."""
    cleaned = [p.rstrip("/") for p in (src_dirs or []) if isinstance(p, str) and p.strip()]
    if not cleaned:
        raise ValueError("src_dirs is empty")
    for p in cleaned:
        if not p.startswith("/"):
            raise ValueError(f"Expected absolute path, got: {p}")
    checks = " ".join(f"test -e {shlex.quote(p)};" for p in cleaned)
    rels = " ".join(shlex.quote(p.lstrip("/")) for p in cleaned)
    return (
        "set -e; "
        f"{checks} "
        "cd /; "
        f"/usr/bin/tar czf {shlex.quote(out_file)} "
        f"{excludes_flags_remote()} "
        f"{rels}"
    )


def ensure_bucket(namespace: str, bucket: str, compartment_id: str, log_file: str) -> int:
    """
    Ensure OCI Object Storage bucket exists (best-effort).
    Common CLI requirement: include --namespace-name for bucket get.
    """
    rc, _ = run_local(
        ["oci", "os", "bucket", "get", "--namespace-name", namespace, "--bucket-name", bucket],
        log_file=log_file,
    )
    if rc == 0:
        return 0
    rc, _ = run_local(
        ["oci", "os", "bucket", "create", "--name", bucket, "--compartment-id", compartment_id],
        log_file=log_file,
    )
    return rc


def upload_to_bucket(namespace: str, bucket: str, file_path: str, log_file: str) -> int:
    """Upload a local file to OCI bucket using OCI CLI."""
    rc, _ = run_local([
        "oci", "os", "object", "put",
        "--namespace", namespace,
        "--bucket-name", bucket,
        "--file", file_path,
        "--force",
    ], log_file=log_file)
    return rc


def delete_local(path: str) -> None:
    """Best-effort local file deletion."""
    try:
        p = Path(path)
        if p.exists():
            p.unlink()
    except Exception:
        pass


def delete_remote_file(
        user: str,
        host: str,
        key: str,
        port: int,
        timeout: int,
        remote_file: str,
        log_file: Optional[str]
) -> None:
    """Best-effort remote rm -f."""
    run_ssh(user, host, key, port, f"rm -f {shlex.quote(remote_file)}", timeout, log_file=log_file)


class MessageCollector:
    """Collect and print WARNING and TODO messages in required WLSDPLY-xxxxx format."""

    def __init__(self):
        self.warnings: List[str] = []
        self.todos: List[str] = []

    def add_warning_not_enough_space_remote(self, machine: str) -> None:
        # Kept generic by design (used for multiple failure causes)
        self.warnings.append(
            f"WLSDPLY-05027: Failed to create the archives automatically on {machine}. "
            f"Please run the commands manually mentioned in the TODO to create the archive, "
            f"scp to the admin host and upload to bucket."
        )

    def add_warning_admin_insufficient_space(
            self,
            machine: str,
            host: str,
            admin_out_dir: str,
            admin_free: int,
            admin_required: int
    ) -> None:
        self.warnings.append(
            f"WLSDPLY-05028: Not enough space on admin host at {admin_out_dir} to receive the largest archive for "
            f"{machine} ({host}). admin_free={fmt_bytes(admin_free)} admin_required~={fmt_bytes(admin_required)}. "
            f"No SCP/upload was attempted. Archives were left on the remote host in /tmp."
        )

    def add_todo_tar_cmd(self, cmd: str) -> None:
        self.todos.append(f"WLSDPLY-06042: Please create the archive using: {cmd}")

    def add_todo_manual_scp(
            self,
            ssh_key: str,   # not displayed (redacted)
            ssh_port: int,
            ssh_user: str,
            host: str,
            remote_tar: str,
            admin_out_dir: str
    ) -> None:
        _ = ssh_key  # deliberately unused (we always redact in the printed TODO)
        self.todos.append(
            "WLSDPLY-06043: Please copy the archive file to admin manually using: "
            f"scp -i <REDACTED_SSH_KEY> -P {ssh_port} {ssh_user}@{host}:{remote_tar} {admin_out_dir}/"
        )

    def add_todo_manual_oci_put(
            self,
            namespace: str,
            bucket: str,
            admin_out_dir: str,
            tar_name: str
    ) -> None:
        self.todos.append(
            "WLSDPLY-06044: Please upload the archive file manually to OSS using: "
            f"oci os object put --namespace {namespace} --bucket-name {bucket} "
            f"--file {admin_out_dir}/{tar_name} --force"
        )

    def print_all(self) -> None:
        if self.warnings:
            print("WARNING Messages:")
            for i, w in enumerate(self.warnings, 1):
                print(f"\t{i}. {w}")
        if self.todos:
            print("TODO Messages:")
            for i, t in enumerate(self.todos, 1):
                print(f"\t{i}. {t}")


def add_host_todos_for_manual_run(
        collector: MessageCollector,
        machine: str,
        domain_name: str,
        node: dict
) -> None:
    """Emit standard WLSDPLY-06042 tar TODOs for a host."""
    base = f"/tmp/{machine}-{domain_name}"
    ex = excludes_flags_todo()

    def rel(p: str) -> str:
        p = (p or "").strip().rstrip("/")
        if not p.startswith("/"):
            raise ValueError(f"Expected absolute path for TODO tar command, got: {p}")
        return p.lstrip("/")

    collector.add_todo_tar_cmd(
        f"cd / && /usr/bin/tar czf {base}-java_home.tar.gz {ex} {rel(node['java_home'])}"
    )
    collector.add_todo_tar_cmd(
        f"cd / && /usr/bin/tar czf {base}-domain_home.tar.gz {ex} {rel(node['domain_home'])}"
    )
    collector.add_todo_tar_cmd(
        f"cd / && /usr/bin/tar czf {base}-weblogic_home.tar.gz {ex} {rel(node['weblogic_home'])}"
    )
    custom_dirs = [p for p in (node.get("custom_dirs") or []) if isinstance(p, str) and p.strip()]
    if custom_dirs:
        paths = " ".join(rel(p) for p in custom_dirs)
        collector.add_todo_tar_cmd(
            f"cd / && /usr/bin/tar czf {base}-custom_dirs.tar.gz {ex} {paths}"
        )


def archive_type_to_src(node: dict, archive_type: str):
    if archive_type == "java_home":
        return node["java_home"]
    if archive_type == "domain_home":
        return node["domain_home"]
    if archive_type == "weblogic_home":
        return node["weblogic_home"]
    if archive_type == "custom_dirs":
        return node.get("custom_dirs") or []
    raise ValueError(f"Unknown archive_type {archive_type}")


def remote_tar_path(machine: str, domain_name: str, archive_type: str) -> str:
    return f"/tmp/{machine}-{domain_name}-{archive_type}.tar.gz"


def required_bytes(estimated_bytes: int, headroom: float) -> int:
    return int(estimated_bytes * headroom) + MIN_FREE_BYTES_FLOOR


def create_one_tar_on_remote(
        ssh_user: str,
        host: str,
        ssh_key: str,
        port: int,
        timeout: int,
        machine: str,
        domain_name: str,
        node: dict,
        archive_type: str,
        log_file: Optional[str]
) -> None:
    """Create one archive tar.gz on remote under /tmp."""
    src = archive_type_to_src(node, archive_type)
    out_tar = remote_tar_path(machine, domain_name, archive_type)

    if archive_type == "custom_dirs":
        paths = list(src)
        if not paths:
            return
        du_paths = paths
    else:
        du_paths = [src]

    free_tmp = remote_free_bytes(ssh_user, host, ssh_key, port, timeout, "/tmp", log_file=log_file)
    raw_bytes = remote_du_bytes(ssh_user, host, ssh_key, port, max(timeout, 30), du_paths, log_file=log_file)
    required_tmp = required_bytes(raw_bytes, REMOTE_SPACE_HEADROOM)

    log_info(
        f"[{machine} {host}] SPACE(/tmp): archive_type={archive_type} "
        f"free={fmt_bytes(free_tmp)} required~={fmt_bytes(required_tmp)} "
        f"input_est={fmt_bytes(raw_bytes)} out_tar={out_tar}",
        log_file
    )

    if free_tmp < required_tmp:
        raise RuntimeError(
            f"Not enough space in /tmp to create {archive_type}. free={free_tmp} required~={required_tmp}"
        )

    cmd = tar_many_dirs_cmd(paths, out_tar) if archive_type == "custom_dirs" else tar_one_dir_cmd(src, out_tar)
    rc, out = run_ssh(ssh_user, host, ssh_key, port, cmd, timeout=max(timeout, 180), log_file=log_file)
    if rc != 0:
        raise RuntimeError(f"tar failed for {archive_type}: {out.strip() or 'no output'}")


def process_host(
        node: dict,
        domain_name: str,
        ssh_user: str,
        ssh_key: str,
        ssh_port: int,
        admin_out_dir: str,
        connect_timeout: int,
        namespace: str,
        bucket: str,
        compartment_id: str,
        skip_transfer: bool,
        log_file: str,
        collector: MessageCollector
) -> None:
    """Run the full workflow for one host."""
    host = node["host"]
    machine = node["machine"]

    log_info(f"[{machine} {host}] Starting host processing (ssh_port={ssh_port}, skip_transfer={skip_transfer})", log_file)

    # SSH precheck
    log_info(f"[{machine} {host}] SSH precheck: running 'echo OK'", log_file)
    rc, out = run_ssh(ssh_user, host, ssh_key, ssh_port, "echo OK", connect_timeout, log_file=log_file)
    if rc != 0:
        log_info(f"[{machine} {host}] SSH precheck FAILED (rc={rc}). Output: {out.strip()}", log_file)
        collector.add_warning_not_enough_space_remote(machine)
        add_host_todos_for_manual_run(collector, machine, domain_name, node)
        return
    log_info(f"[{machine} {host}] SSH precheck OK", log_file)

    # Archive types for this host
    types: List[str] = []
    for t in ARCHIVE_ORDER:
        if t == "custom_dirs" and not (node.get("custom_dirs") or []):
            continue
        types.append(t)
    log_info(f"[{machine} {host}] Archive types to process: {types}", log_file)

    # Estimate largest for admin gating (remote du-based)
    log_info(f"[{machine} {host}] Estimating archive input sizes using remote du", log_file)
    try:
        du_estimates: Dict[str, int] = {}
        for t in types:
            src = archive_type_to_src(node, t)
            du_paths = list(src) if t == "custom_dirs" else [src]
            log_info(f"[{machine} {host}] du estimate for {t}: paths={du_paths}", log_file)
            du_estimates[t] = remote_du_bytes(
                ssh_user, host, ssh_key, ssh_port, max(connect_timeout, 30),
                du_paths, log_file=log_file
            )
            log_info(
                f"[{machine} {host}] du estimate result for {t}: "
                f"{du_estimates[t]} bytes ({fmt_bytes(du_estimates[t])})",
                log_file
            )
    except Exception as e:
        log_info(f"[{machine} {host}] ERROR during du estimates: {type(e).__name__}: {e}", log_file)
        collector.add_warning_not_enough_space_remote(machine)
        add_host_todos_for_manual_run(collector, machine, domain_name, node)
        return

    largest_du = max(du_estimates.values(), default=0)
    admin_required = required_bytes(largest_du, ADMIN_SPACE_HEADROOM)
    admin_free = admin_free_bytes(admin_out_dir)

    log_info(
        f"[{machine} {host}] Admin free space check at {admin_out_dir}: "
        f"admin_free={admin_free} ({fmt_bytes(admin_free)}), "
        f"largest_input={largest_du} ({fmt_bytes(largest_du)}), "
        f"admin_required~={admin_required} ({fmt_bytes(admin_required)})",
        log_file
    )

    # Host-level gating: if admin can't accept largest, do NOT SCP at all for this host
    if admin_free < admin_required:
        log_info(
            f"[{machine} {host}] Admin gating triggered (insufficient space). "
            f"Will create ALL tars on remote /tmp and skip SCP/upload for this host.",
            log_file
        )
        # Create all tars on remote /tmp (tar-by-tar)
        try:
            for t in types:
                log_info(f"[{machine} {host}] Creating remote tar for {t} (admin gating mode)", log_file)
                create_one_tar_on_remote(
                    ssh_user, host, ssh_key, ssh_port, connect_timeout,
                    machine, domain_name, node, t, log_file=log_file
                )
                log_info(f"[{machine} {host}] Created remote tar: {remote_tar_path(machine, domain_name, t)}", log_file)
        except Exception as e:
            log_info(f"[{machine} {host}] ERROR creating remote tars (admin gating mode): {type(e).__name__}: {e}", log_file)
            collector.add_warning_not_enough_space_remote(machine)
            add_host_todos_for_manual_run(collector, machine, domain_name, node)
            return

        collector.add_warning_admin_insufficient_space(machine, host, admin_out_dir, admin_free, admin_required)

        # Manual commands (OCI TODOs only if skip_transfer is False)
        for t in types:
            remote_tar = remote_tar_path(machine, domain_name, t)
            tar_name = Path(remote_tar).name
            log_info(f"[{machine} {host}] Emitting manual SCP TODO for {remote_tar}", log_file)
            collector.add_todo_manual_scp(ssh_key, ssh_port, ssh_user, host, remote_tar, admin_out_dir)
            if not skip_transfer:
                log_info(f"[{machine} {host}] Emitting manual OCI PUT TODO for {tar_name}", log_file)
                collector.add_todo_manual_oci_put(namespace, bucket, admin_out_dir, tar_name)

        log_info(f"[{machine} {host}] Completed host processing with admin gating (no SCP/upload attempted).", log_file)
        return

    # Normal flow: tar -> scp -> (optional oci put) -> cleanup, per archive type
    Path(admin_out_dir).mkdir(parents=True, exist_ok=True)
    log_info(f"[{machine} {host}] Admin gating passed. Using admin_out_dir={admin_out_dir}", log_file)

    # Only validate/create bucket if we're actually transferring to OCI
    bucket_ok = True
    if not skip_transfer:
        log_info(f"[{machine} {host}] Ensuring bucket exists: bucket={bucket} compartment_id={compartment_id}", log_file)
        bucket_ok = (ensure_bucket(namespace, bucket, compartment_id, log_file) == 0)
        log_info(f"[{machine} {host}] ensure_bucket result: bucket_ok={bucket_ok}", log_file)
    else:
        log_info(f"[{machine} {host}] skip_transfer=True; will not ensure bucket or upload to OCI.", log_file)

    for t in types:
        remote_tar = remote_tar_path(machine, domain_name, t)
        tar_name = Path(remote_tar).name
        local_tar = str(Path(admin_out_dir) / tar_name)

        # 1) create tar in /tmp
        try:
            log_info(f"[{machine} {host}] [{t}] Creating remote tar: {remote_tar}", log_file)
            create_one_tar_on_remote(
                ssh_user, host, ssh_key, ssh_port, connect_timeout,
                machine, domain_name, node, t, log_file=log_file
            )
            log_info(f"[{machine} {host}] [{t}] Remote tar created: {remote_tar}", log_file)
        except Exception as e:
            log_info(f"[{machine} {host}] [{t}] ERROR creating remote tar: {type(e).__name__}: {e}", log_file)
            collector.add_warning_not_enough_space_remote(machine)
            add_host_todos_for_manual_run(collector, machine, domain_name, node)
            return

        # 2) scp to admin out
        log_info(f"[{machine} {host}] [{t}] SCP to admin_out_dir: {remote_tar} -> {admin_out_dir}", log_file)
        rc, out = scp_get(
            ssh_user, host, ssh_key, ssh_port, remote_tar, admin_out_dir, connect_timeout,
            log_file=log_file
        )
        if rc != 0:
            log_info(f"[{machine} {host}] [{t}] SCP FAILED (rc={rc}). Output: {out.strip()}", log_file)
            # Leave remote tar in /tmp; provide manual steps
            collector.add_todo_manual_scp(ssh_key, ssh_port, ssh_user, host, remote_tar, admin_out_dir)
            if not skip_transfer:
                collector.add_todo_manual_oci_put(namespace, bucket, admin_out_dir, tar_name)
            return

        log_info(f"[{machine} {host}] [{t}] SCP OK. Local tar: {local_tar}", log_file)

        # 3) upload to OSS (from admin) - SKIP when skip_transfer=True
        if skip_transfer:
            log_info(f"[{machine} {host}] [{t}] skip_transfer=True; skipping OCI upload. Cleaning up remote tar only.", log_file)
            delete_remote_file(ssh_user, host, ssh_key, ssh_port, connect_timeout, remote_tar, log_file=log_file)
            log_info(f"[{machine} {host}] [{t}] Remote tar deleted: {remote_tar}. Local tar retained: {local_tar}", log_file)
            continue

        if not bucket_ok:
            log_info(f"[{machine} {host}] [{t}] Bucket not OK; emitting manual OCI PUT TODO for {tar_name} and stopping.", log_file)
            collector.add_todo_manual_oci_put(namespace, bucket, admin_out_dir, tar_name)
            return

        log_info(f"[{machine} {host}] [{t}] Uploading to OCI: namespace={namespace} bucket={bucket} file={local_tar}", log_file)
        rc = upload_to_bucket(namespace, bucket, local_tar, log_file)
        if rc != 0:
            log_info(f"[{machine} {host}] [{t}] OCI upload FAILED (rc={rc}); emitting manual OCI PUT TODO and stopping.", log_file)
            collector.add_todo_manual_oci_put(namespace, bucket, admin_out_dir, tar_name)
            return

        log_info(f"[{machine} {host}] [{t}] OCI upload OK; cleaning up local+remote tars", log_file)

        # 4) cleanup local + remote after successful upload
        delete_local(local_tar)
        delete_remote_file(ssh_user, host, ssh_key, ssh_port, connect_timeout, remote_tar, log_file=log_file)
        log_info(f"[{machine} {host}] [{t}] Cleanup complete (deleted local={local_tar}, remote={remote_tar})", log_file)

    log_info(f"[{machine} {host}] Completed host processing successfully.", log_file)


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(
        description="WLS multi-node archiver (host-gated admin space, WARNING/TODO format)."
    )
    ap.add_argument("--input-model", required=True, help="Path to infra_output / wlsdomain JSON")
    ap.add_argument(
        "--tool-home",
        default=None,
        help="Optional override for tool_home; default derived from script path tool_home/lib/python",
    )
    ap.add_argument(
        "--ssh-ports",
        default=None,
        help="Optional override for ssh-ports.json path; default tool_home/config/ssh-ports.json",
    )
    return ap.parse_args()


def main() -> int:
    args = parse_args()

    script_path = Path(__file__).resolve()
    default_tool_home = script_path.parents[2]  # .../tool_home/lib/python/script.py -> tool_home
    tool_home = Path(args.tool_home).resolve() if args.tool_home else default_tool_home

    config_dir = tool_home / "config"
    on_prem_env = config_dir / "on-prem.env"
    admin_out_dir = tool_home / "out"
    log_file = str(tool_home / "logs" / "migration_script.log")

    env = load_env_from_on_prem_env(str(on_prem_env))
    ssh_user = require(env, "ssh_user", str(on_prem_env))
    ssh_key = require(env, "ssh_private_key_file", str(on_prem_env))
    skip_transfer = env.get("skip_transfer", "false").strip().lower() == "true"

    if not skip_transfer:
        bucket = require(env, "bucket_name", str(on_prem_env))
        namespace = require(env, "tenancy_namespace", str(on_prem_env))
        compartment_id = require(env, "compartment_ocid", str(on_prem_env))
    else:
        bucket = namespace = compartment_id = ""

    connect_timeout = int(env.get("ssh_connect_timeout", "10"))

    ssh_ports_path = Path(args.ssh_ports) if args.ssh_ports else Path(
        env.get("ssh_ports_json", str(config_dir / "ssh-ports.json"))
    )

    ssh_ports_map: Dict[str, int] = {}
    if ssh_ports_path.is_file():
        ssh_ports_map_raw = json.loads(ssh_ports_path.read_text(encoding="utf-8"))
        if not isinstance(ssh_ports_map_raw, dict):
            raise ValueError(f"{ssh_ports_path} must be a JSON object of host->port")
        for k, v in ssh_ports_map_raw.items():
            try:
                ssh_ports_map[str(k)] = int(v)
            except Exception:
                pass

    if not Path(ssh_key).exists():
        print(f"ERROR: ssh_private_key_file does not exist: {ssh_key}", file=sys.stderr)
        return 2

    wlsdomain = json.loads(Path(args.input_model).read_text(encoding="utf-8"))
    domain_name, nodes = build_plan_from_wlsdomain(wlsdomain)

    log_info(
        f"Starting archive run: domain={domain_name}, hosts={len(nodes)}, skip_transfer={skip_transfer}, admin_out_dir={admin_out_dir}",
        log_file
    )

    collector = MessageCollector()

    for node in nodes:
        host = node["host"]
        port = int(ssh_ports_map.get(host, 22))
        process_host(
            node=node,
            domain_name=domain_name,
            ssh_user=ssh_user,
            ssh_key=ssh_key,
            ssh_port=port,
            admin_out_dir=str(admin_out_dir),
            connect_timeout=connect_timeout,
            namespace=namespace,
            bucket=bucket,
            compartment_id=compartment_id,
            skip_transfer=skip_transfer,
            log_file=log_file,
            collector=collector,
        )

    collector.print_all()
    log_info("Archive run complete.", log_file)
    return 0


if __name__ == "__main__":
    sys.exit(main())