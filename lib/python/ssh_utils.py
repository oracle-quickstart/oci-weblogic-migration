"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

"""

import subprocess
from typing import Optional


class SSHUtils:
    """
    SSHUtils provides a simple interface for running commands remotely over SSH. It handles optional username and
    private key configuration, executes commands, and captures both stdout and stderr outputs.
    """

    def __init__(self, user=None, key_file=None):
        """
        Initialize SSHUtils with optional authentication parameters.

        Args:
            user (Optional[str]): SSH username to prefix the hostname (e.g., "oracle").
                                   If None, default SSH user is used.
            key_file (Optional[str]): Path to a private SSH key file for key-based auth.
        """

        self.user = user
        self.key_file = key_file

    def execute_ssh_command(self, hostname, command):
        """
        Execute a shell command on a remote host via SSH and return its output.
        Constructs the SSH command, including user@hostname and optional key file, then runs it via subprocess.run, capturing both stdout and stderr.
        Args:
            hostname (str): The remote host's name or IP address.
            command (str): The shell command to execute on the remote host.
        Returns:
            subprocess.CompletedProcess:
            Always returns a CompletedProcess object containing:
              - args: the full SSH command that was run
              - stdout: the command's standard output (maybe empty)
              - stderr: the command's standard error (may contain the error message)
              - returncode: 0 on success or non-zero on failure
        """

        ssh_command = ["ssh"]
        try:
            if self.key_file:
                ssh_command.extend(["-i", self.key_file])
            target = f"{self.user}@{hostname}" if self.user else hostname
            ssh_command.extend([target, command])

            result = subprocess.run(
                ssh_command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                check=True
            )
            return result

        except subprocess.CalledProcessError as e:
            # Return a CompletedProcess carrying the stderr and exit code
            return subprocess.CompletedProcess(args=e.cmd, returncode=e.returncode, stdout="", stderr=e.stderr, )
        except Exception as e:
            # Any other exception: capture its message in stderr
            return subprocess.CompletedProcess(args=ssh_command, returncode=-1,stdout="", stderr=str(e), )
