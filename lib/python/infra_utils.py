import json
from typing import List, Dict, Any


class InfraUtils:
    """
    Loads and parses an infrastructure JSON file to extract machine hostnames or other metadata.
    """

    def __init__(self, infra_file_path: str):
        """
        Initialize the loader with a path to the infra JSON file.
        Args:
            infra_file_path (str): Filesystem path to the JSON file containing
                                   infrastructure definitions and metadata.
        """

        self.infra_file_path = infra_file_path
        self._data: Dict[str, Any] = {}
        self._machines: Dict[str, Any] = {}
        self._load_json()

    def _load_json(self) -> None:
        """
        Internal helper: Load and parse the JSON file into memory, populating self._data and self._machines.
        """

        with open(self.infra_file_path, 'r') as f:
            self._data = json.load(f)
        # Normalize path or validate structure if needed
        self._machines = self._data.get("resources", {}).get("Machines", {})

    def get_machine_hostnames(self) -> List[str]:
        """
        Retrieve a list of all hostnames defined in the infrastructure.
        Iterates over each machine entry under "Machines" and extracts the
        "DETAILS" → "Hostname" field if present.

        Returns:
            List[str]: A list of hostname strings for each configured machine.
        """
        hostnames: List[str] = []
        for machine_name, machine_info in self._machines.items():
            details = machine_info.get("DETAILS", {})
            hostname = details.get("Hostname")
            if hostname:
                hostnames.append(hostname)
        return hostnames

    def get_machine_property(self, hostname: str, key: str) -> Any:
        """
        Generic fetch of a top‑level property from a machine entry.
        Args:
            hostname (str): Name of the host whose entry to look up.
            key (str): The top‑level field name under Machines[...], e.g. "ExtraOSPaths", "SomeOtherKey".

        Returns:
            Any: The value of that field (e.g. a list), or None if the host or key is not found.
        """

        for machine_info in self._machines.values():
            if machine_info.get("DETAILS", {}).get("Hostname") == hostname:
                return machine_info.get(key)
        return []
