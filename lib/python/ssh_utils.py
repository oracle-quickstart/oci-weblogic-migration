import subprocess
from typing import Optional


class SSHUtils:
    """
    SSHUtils provides a simple interface for running commands remotely over SSH. It handles optional username and
    private key configuration, executes commands, and captures both stdout and stderr outputs.
    """

    def __init__(self, user: Optional[str] = None, key_file: Optional[str] = None):
        """
        Initialize SSHUtils with optional authentication parameters.

        Args:
            user (Optional[str]): SSH username to prefix the hostname (e.g., "oracle").
                                   If None, default SSH user is used.
            key_file (Optional[str]): Path to a private SSH key file for key-based auth.
        """

        self.user = user
        self.key_file = key_file

    def execute_ssh_command(self, hostname: str, command: str) -> str:
        """
        Execute a shell command on a remote host via SSH and return its output.
        Constructs the SSH command, including user@hostname and optional key file, then runs it via subprocess.run, capturing both stdout and stderr.
        Args:
            hostname (str): The remote host's name or IP address.
            command (str): The shell command to execute on the remote host.
        Returns:
            str: If successful, returns the stdout stripped of trailing newlines.
                 If the command fails, returns a string starting with "Error:"
                 followed by the stderr output or exception message.
        """

        try:
            ssh_command = ["ssh"]
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
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            return f"Error: {e.stderr.strip()}"
        except Exception as e:
            return f"An unexpected error occurred: {str(e)}"
