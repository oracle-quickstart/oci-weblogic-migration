import os
import json
import argparse
import shutil
import subprocess

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

def execute_ssh_command(hostname, command):
    """
    Execute a shell command on a remote host over SSH.

    Args:
        hostname (str): The remote host's name or IP address.
        command (str): Command string to run on the remote host.

    Returns:
        str: Output of the SSH command or error message.
    """
    try:
        ssh_command = ["ssh", hostname, command]
        result = subprocess.run(ssh_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error: {e.stderr.strip()}"
    except Exception as e:
        return f"An unexpected error occurred: {str(e)}"

def retrieve_remote_env_var_path(hostname, env_var_name):
    """
    Retrieve the resolved path of an environment variable on a remote host.

    This function checks if the variable is set directly or declared in .bash_profile or .bashrc.

    Args:
        hostname (str): Remote host.
        env_var_name (str): Name of the environment variable.

    Returns:
        str: Resolved (canonical) path or raw value of the environment variable.
    """
    cmd = (
        f'VAR_VALUE=${env_var_name}; '
        f'[ -z "$VAR_VALUE" ] && VAR_VALUE=$(grep -h {env_var_name} ~/.bash_profile ~/.bashrc 2>/dev/null | '
        f'awk -F "=" \'{{print $2}}\' | tr -d \'"\' | tail -n 1); '
        f'readlink -f "$VAR_VALUE" || echo "$VAR_VALUE"'
    )
    result = execute_ssh_command(hostname, cmd)
    if '=' in result:
        return result.split('=')[-1].strip('"').strip()
    return result.strip()

def get_remote_directory_size_bytes(hostname, directory_path):
    """
    Get the size of a directory on a remote host in bytes.

    Args:
        hostname (str): Remote host.
        directory_path (str): Absolute path to the remote directory.

    Returns:
        int: Directory size in bytes, or 0 if the command fails.
    """
    cmd = f"du -sb {directory_path} 2>/dev/null | cut -f1"
    result = execute_ssh_command(hostname, cmd)
    try:
        return int(result)
    except ValueError:
        return 0

def get_local_free_space_mb(directory_path):
    """
    Check available free disk space in megabytes for a local directory.

    Args:
        directory_path (str): Local path to check for free space.

    Returns:
        float: Free disk space in megabytes.
    """
    total, used, free = shutil.disk_usage(directory_path)
    return free / (1024 ** 2)

def main():
    """
    Main execution flow:
    - Parse input arguments.
    - Load remote hostnames from the infrastructure file.
    - Retrieve paths of environment variables from each host.
    - Measure remote directory sizes.
    - Compare total remote size to local available disk space.
    """
    parser = argparse.ArgumentParser(
        description="Check if the local system has enough space to store archives from remote WebLogic environments."
    )
    parser.add_argument(
        "--infrafile",
        type=str,
        required=True,
        help="Path to infrastructure JSON file containing host details."
    )
    args = parser.parse_args()

    # Derive tool's root directory from script location
    script_path = os.path.realpath(__file__)
    tool_home = os.path.abspath(os.path.join(script_path, "..", "..", ".."))

    # Load hostnames from infrastructure file
    hosts = load_hostnames_from_infrastructure(args.infrafile)
    total_size_mb = 0

    for host in hosts:
        print(f"\n----- {host} -----")
        for env_var in ["ORACLE_HOME", "DOMAIN_HOME", "JAVA_HOME"]:
            path = retrieve_remote_env_var_path(host, env_var)
            if not path or "not found" in path.lower():
                print(f"{env_var}: Not found.")
                continue

            size_bytes = get_remote_directory_size_bytes(host, path)
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
