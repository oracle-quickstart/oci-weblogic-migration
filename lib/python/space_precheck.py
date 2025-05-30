import os
import json
import argparse
import shutil
import subprocess
import sys
try:
    import paramiko
except ModuleNotFoundError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paramiko"])
    import paramiko

def load_ssh_config(env_file_path):
    """
    Load SSH configuration parameters from a given environment file.

    Args:
        env_file_path (str): Path to the environment file containing SSH config variables.

    Returns:
        dict: Dictionary of SSH config variables (e.g., ssh_user, ssh_private_key_file).
    """
    ssh_config = {}
    with open(env_file_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                ssh_config[key.strip()] = val.strip().strip('"')
    return ssh_config

def load_hostnames_from_infrastructure(infra_file_path):
    """
    Parse infrastructure JSON file to extract hostnames of machines.

    Args:
        infra_file_path (str): Path to the JSON infrastructure file.

    Returns:
        list: List of hostnames extracted from the infrastructure.
    """
    with open(infra_file_path) as f:
        data = json.load(f)
        machines = data.get("resources", {}).get("Machines", {})
        hostnames = []
        for machine_name, machine_info in machines.items():
            details = machine_info.get("DETAILS", {})
            hostname = details.get("Hostname")
            if hostname:
                hostnames.append(hostname)
        return hostnames

def execute_ssh_command(hostname, username, private_key_path, command):
    """
    Execute a command on a remote host over SSH.

    Args:
        hostname (str): The remote host's name or IP address.
        username (str): SSH username.
        private_key_path (str): Path to the private key file for SSH authentication.
        command (str): Command string to run on the remote host.

    Returns:
        str: Output of the SSH command or error message.
    """
    try:
        key = paramiko.RSAKey.from_private_key_file(private_key_path)
        ssh_client = paramiko.SSHClient()
        ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh_client.connect(hostname, username=username, pkey=key)

        stdin, stdout, stderr = ssh_client.exec_command(command)
        output = stdout.read().decode().strip()
        ssh_client.close()
        return output
    except Exception as e:
        return f"SSH ERROR: {e}"

def retrieve_remote_env_var_path(hostname, username, private_key_path, env_var_name):
    """
    Retrieve the resolved path of an environment variable on a remote host.

    Checks if the variable is set directly or in the .bash_profile/.bashrc,
    and returns the canonical (absolute) path.

    Args:
        hostname (str): Remote host.
        username (str): SSH username.
        private_key_path (str): SSH private key path.
        env_var_name (str): Name of the environment variable to retrieve.

    Returns:
        str: Resolved path or raw value of the environment variable.
    """
    # Shell command to get variable value or fallback to .bash_profile/.bashrc
    cmd = (
        f'VAR_VALUE=${env_var_name}; '
        f'[ -z "$VAR_VALUE" ] && VAR_VALUE=$(grep -h {env_var_name} ~/.bash_profile ~/.bashrc 2>/dev/null | '
        f'awk -F "=" \'{{print $2}}\' | tr -d \'"\' | tail -n 1); '
        f'readlink -f "$VAR_VALUE" || echo "$VAR_VALUE"'
    )
    result = execute_ssh_command(hostname, username, private_key_path, cmd)
    if '=' in result:
        return result.split('=')[-1].strip('"').strip()
    return result.strip()

def get_remote_directory_size_bytes(hostname, username, private_key_path, directory_path):
    """
    Get the size in bytes of a directory on a remote host.

    Args:
        hostname (str): Remote host.
        username (str): SSH username.
        private_key_path (str): SSH private key path.
        directory_path (str): Path of the directory to measure.

    Returns:
        int: Directory size in bytes, or 0 if error/does not exist.
    """
    cmd = f"du -sb {directory_path} 2>/dev/null | cut -f1"
    result = execute_ssh_command(hostname, username, private_key_path, cmd)
    try:
        return int(result)
    except ValueError:
        return 0

def get_local_free_space_mb(directory_path):
    """
    Calculate the available free disk space in megabytes for a local directory.

    Args:
        directory_path (str): Path of the directory to check.

    Returns:
        float: Free space in MB.
    """
    total, used, free = shutil.disk_usage(directory_path)
    free_mb = free / (1024 ** 2)
    return free_mb

def main():
    parser = argparse.ArgumentParser(
        description="Precheck script to verify available local disk space "
                    "against the total size of remote WebLogic archive directories."
    )
    parser.add_argument(
        "--infrafile",
        type=str,
        required=True,
        help="Path to the infrastructure JSON file containing host information."
    )
    args = parser.parse_args()

    # Derive paths relative to this script location
    script_path = os.path.realpath(__file__)
    tool_home = os.path.abspath(os.path.join(script_path, "..", "..", ".."))
    env_path = os.path.join(tool_home, "config", "on-prem.env")

    ssh_config = load_ssh_config(env_path)
    ssh_user = ssh_config.get("ssh_user")
    ssh_key_path = ssh_config.get("ssh_private_key_file")
    if not ssh_user or not ssh_key_path:
        print("ERROR: 'ssh_user' or 'ssh_private_key_file' missing in on-prem.env.")
        return

    hosts = load_hostnames_from_infrastructure(args.infrafile)
    total_size_mb = 0

    for host in hosts:
        print(f"\n----- {host} -----")
        for env_var in ["ORACLE_HOME", "DOMAIN_HOME", "JAVA_HOME"]:
            path = retrieve_remote_env_var_path(host, ssh_user, ssh_key_path, env_var)
            if not path or "not found" in path.lower():
                print(f"{env_var}: Not found.")
                continue

            size_bytes = get_remote_directory_size_bytes(host, ssh_user, ssh_key_path, path)
            size_mb = size_bytes / (1024 ** 2)
            print(f"{env_var} size on {host}: {size_mb:.2f} MB")
            total_size_mb += size_mb

    output_dir = os.path.join(tool_home, "out")
    available_space_mb = get_local_free_space_mb(output_dir)

    print(f"\nTotal remote archive size: {total_size_mb:.2f} MB")
    print(f"Available local disk space: {available_space_mb:.2f} MB")

    if available_space_mb >= total_size_mb * 1.2:
        print("Sufficient space is available to store the archives on the admin VM.")
    else:
        print("Insufficient space to store the archives on the admin VM.")

if __name__ == "__main__":
    main()
