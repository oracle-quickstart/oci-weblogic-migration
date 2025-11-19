"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

"""

import os
import argparse
import shutil
from infra_utils import InfraUtils
from ssh_utils import SSHUtils
import json
import sys


class SpacePrecheck:
    """
    Perform a pre‐check of disk space before archiving remote WebLogic environments.
    This class:
      1. Loads an infrastructure JSON to find all target hosts.
      2. SSH’s into each host and discovers key environment directories:
         - ORACLE_HOME
         - DOMAIN_HOME
         - JAVA_HOME
      3. Optionally includes any extra OS paths defined under “ExtraOSPaths” in that infra.
      4. Runs `du -sb` remotely to compute each directory’s size in bytes.
      5. Sums those sizes per host and across all hosts.
      6. Checks local free space (in an “out” folder) in megabytes.
      7. Prints per‐host and overall totals, and decides if a 20% safety margin is met.
    """

    def __init__(self, infra_file: str):
        """
        Initializes the SpacePrecheck class with the infrastructure file.
        Args:
            infra_file (str): Path to the infrastructure JSON file containing remote host details.
        """
        self.infra_file = infra_file
        self.loader = InfraUtils(infra_file)
        self.ssh = SSHUtils()

    def get_local_free_space_mb(self, directory_path: str) -> float:
        """
        Check available free disk space in megabytes for a local directory.
        Args:
            directory_path (str): Local path to check for free space.
        Returns:
            float: Free disk space in megabytes.
        """
        total, used, free = shutil.disk_usage(directory_path)
        return free / (1024 ** 2)

    def retrieve_remote_env_var_path(self, hostname: str, env_var_name: str) -> str:
        """
        Resolve a remote environment variable to an absolute path.
        1. Reads `$ENV_VAR_NAME` directly.
        2. If empty, greps ~/.bash_profile and ~/.bashrc for a definition.
        3. Uses `readlink -f` to canonicalize (resolve symlinks).
        4. Falls back to raw value if readlink fails.
        5. Returns an empty string on errors or if nothing is found.
        Args:
            hostname (str): Remote host.
            env_var_name (str): Name of the environment variable.
        Returns:
            str: Resolved (canonical) path or raw value of the environment variable.
        """

        cmd = f'''VAR_VALUE=${{{env_var_name}}}; [ -z "$VAR_VALUE" ] && VAR_VALUE=$(grep -h "^{env_var_name}=" ~/.bash_profile ~/.bashrc 2>/dev/null | awk -F "=" '{{print $2}}' | tr -d '"' | tail -n1); readlink -f "$VAR_VALUE" || echo "$VAR_VALUE"'''
        result = self.ssh.execute_ssh_command(hostname, cmd)
        result_out = result.stdout.strip()
        result_err = result.stderr.strip()
        # If the SSH command failed or produced no output, skip
        if result.returncode != 0 or not result_out:
            print(f"Error: {result_err}")
            return ""
        return result_out

    def get_remote_directory_size_bytes(self, hostname: str, directory_path: str) -> int:
        """
        Compute the size of a remote directory in bytes. Runs: `du -sb <directory_path> 2>/dev/null | cut -f1`
        Args:
            hostname (str): Remote host.
            directory_path (str): Absolute path to the remote directory.
        Returns:
            int: Directory size in bytes, or Returns 0 on failure or invalid input.
        """
        if not directory_path:
            return 0
        cmd = f"du -sb {directory_path} 2>/dev/null | cut -f1"
        result = self.ssh.execute_ssh_command(hostname, cmd)
        result_out = result.stdout.strip()
        try:
            return int(result_out)
        except (ValueError, TypeError):
            return 0

    def run(self):
        """
        Run pre‐check:
          - Load hostnames.
          - For each host, resolve ORACLE_HOME, DOMAIN_HOME, JAVA_HOME and any ExtraOSPaths,
            compute their sizes in MB, and print per‐host totals plus current local free space.
          - Finally, print the combined total and verify it fits within local free space ×1.2.
        """
        # Gather all hosts from the infra JSON
        hosts = self.loader.get_machine_hostnames()
        total_size_mb = 0.0
        host_statuses = []  # collect per-host status

        # Prepare the local “out” folder path for free‐space checks
        script_path = os.path.realpath(__file__)
        tool_home = os.path.abspath(os.path.join(script_path, "..", "..", ".."))
        output_dir = os.path.join(tool_home, "out")
        max_archive_mb = 0.0
        # Loop each host and measure remote directories
        for host in hosts:
            print(f"\n----- {host} -----")
            host_size_mb = 0.0  # reset per‐host accumulator
            max_host_archive_mb = 0.0

            # Standard WebLogic env vars
            for env_var in ("ORACLE_HOME", "DOMAIN_HOME", "JAVA_HOME"):
                # Attempt to resolve each environment variable path
                path = self.retrieve_remote_env_var_path(host, env_var)

                # Fallback: if not found via SSH, try from infra JSON
                if not path or str(path).strip() == "" or "not found" in str(path).lower():
                    print(f"{env_var}: Not found via SSH. Checking infra JSON...")
                    if env_var == "ORACLE_HOME":
                        path = self.loader.get_machine_property(host, "OraclePath") \
                               or self.loader.get_topology_property("OraclePath")
                    elif env_var == "DOMAIN_HOME":
                        path = self.loader.get_machine_property(host, "DomainPath") \
                               or self.loader.get_topology_property("DomainPath")
                    elif env_var == "JAVA_HOME":
                        path = self.loader.get_machine_property(host, "JavaPath") \
                               or self.loader.get_topology_property("NMProperties.JavaHome")

                # Final check: treat None or empty string as not found
                if not path or str(path).strip() == "":
                    print(f"{env_var}: Still not found. Skipping host {host}.")
                    return "", 2

                # Get directory size in bytes and convert to MB
                size_bytes = self.get_remote_directory_size_bytes(host, path)
                size_mb = size_bytes / (1024 ** 2)
                # accumulate both per‐host and grand total
                host_size_mb += size_mb
                total_size_mb += size_mb
                max_host_archive_mb = max(max_host_archive_mb, size_mb)

            # Any extra paths defined in infra under “ExtraOSPaths”
            extra_paths = self.loader.get_machine_property(host, "ExtraOSPaths") or []
            for extra in extra_paths:
                size_bytes = self.get_remote_directory_size_bytes(host, extra)
                size_mb = size_bytes / (1024 ** 2)
                host_size_mb += size_mb
                total_size_mb += size_mb
                max_host_archive_mb = max(max_host_archive_mb, size_mb)

            # Report per‐host archive total and local free space
            print(f"Total remote archive size for {host}: {host_size_mb:.2f} MB")

            # Report the largest size of archive in the host
            print(f"Largest size of remote archive size for {host}: {max_host_archive_mb:.2f} MB")

            # show available local space per host
            available_space_mb = self.get_local_free_space_mb(output_dir)
            print(f"Available local disk space on {host}: {available_space_mb:.2f} MB")

            max_archive_mb = max(max_host_archive_mb, max_archive_mb)

            # determine per-host status (0=sufficient,1=insufficient)
            status = 0 if available_space_mb >= max_host_archive_mb * 1.2 else 1
            host_statuses.append([host, status])

        available_space_mb = self.get_local_free_space_mb(output_dir)

        print(f"\n-----------------------------------------------")
        # Summary report
        print(f"\nLargest archive size among all the hosts: {max_archive_mb:.2f} MB")
        print(f"\nTotal remote archive size combined: {total_size_mb:.2f} MB")
        print(f"Available local disk space on admin VM: {available_space_mb:.2f} MB")

        # Decision based on 20% safety buffer for combined size
        overall_status = 0 if (available_space_mb >= total_size_mb * 1.2) else 1
        if overall_status == 0:
            print("Sufficient space is available to store all nodes archives on the admin VM.")
        else:
            print("Insufficient space to store all nodes archives on the admin VM.")

        per_archive_status = 0 if (available_space_mb >= max_archive_mb * 1.2) else 1
        if per_archive_status == 0:
            print("Sufficient space is available to store the largest archive among all the hosts on the admin VM.")
        else:
            print("Insufficient space to store the largest archive among all the hosts on the admin VM.")

        print(f"\n-----------------------------------------------")
        # Convert host_statuses to a dictionary
        host_status_dict = {host: status for host, status in host_statuses}
        return host_status_dict, per_archive_status, overall_status  # return host_statuses , per archive status and overall status code


def main():
    """
    CLI entry point to run the space precheck.
    Parses:
      --infrafile  Path to the JSON infra description.
    """
    parser = argparse.ArgumentParser(
        description="Check if the local system has enough space to store archives from remote WebLogic environments."
    )
    parser.add_argument(
        "--infrafile", required=True,
        help="Path to infrastructure JSON file containing host details."
    )
    args = parser.parse_args()

    check_space = SpacePrecheck(args.infrafile)
    host_statuses, per_archive_status, overall_status = check_space.run()
    print(f"The hostname : 0 if space is there else 1- {(json.dumps(host_statuses))}")
    print(f"Per archive returncode: {per_archive_status}")
    print(f"Admin returncode: {overall_status}")  # send JSON to stdout for shell to consume
    sys.exit(overall_status)  # exit with admin status code only


if __name__ == "__main__":
    main()
