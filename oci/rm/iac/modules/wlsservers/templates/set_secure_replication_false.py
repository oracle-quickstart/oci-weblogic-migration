#
# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
#
import sys
import os
import shutil
from xml.dom import minidom
from datetime import datetime

def create_backup(config_path):
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = f"{config_path}.backup_{timestamp}"
    shutil.copy2(config_path, backup_path)
    print(f"[INFO] Backup created: {backup_path}")
    return backup_path

def is_secure_mode_enabled(dom):
    secure_mode_nodes = dom.getElementsByTagName("secure-mode-enabled")
    for node in secure_mode_nodes:
        if node.firstChild:
            value = node.firstChild.nodeValue.strip().lower()
            if value == "true":
                return True
    return False

def update_secure_replication(config_path):
    if not os.path.exists(config_path):
        print(f"[ERROR] File not found: {config_path}")
        sys.exit(1)
    backup_path = None
    try:
        dom = minidom.parse(config_path)
        domain = dom.getElementsByTagName("domain")[0]
        # check domain version
        version_nodes = domain.getElementsByTagName("domain-version")
        domain_version = version_nodes[0].firstChild.nodeValue.strip() if version_nodes else None
        if not domain_version:
            print("[ERROR] Could not determine domain version")
            sys.exit(1)
        print(f"[INFO] Domain version: {domain_version}")
        if not domain_version.startswith("12.2.1.4"):
            print(f"[INFO] Domain version is {domain_version}, not 12.2.1.4 - no update needed")
            return
        # check if secured mode is enabled
        if not is_secure_mode_enabled(dom):
            print("[INFO] Secure mode is not enabled - no update needed")
            return
        print("[INFO] Secure mode is enabled - checking secure-replication-enabled")
        # find <secure-replication-enabled>
        secure_rep_nodes = dom.getElementsByTagName("secure-replication-enabled")
        if not secure_rep_nodes:
            print("[INFO] <secure-replication-enabled> element not found in config.xml")
            print("[INFO] No update needed (element will default to false)")
            return
        node = secure_rep_nodes[0]
        current_value = node.firstChild.nodeValue.strip().lower() if node.firstChild else ""
        if current_value == "false":
            print("[INFO] <secure-replication-enabled> is already set to 'false' - no change needed")
            return
        # create backup before we make changes
        backup_path = create_backup(config_path)
        # update the value
        print(f"[INFO] Changing <secure-replication-enabled> from '{current_value}' to 'false'")
        if node.firstChild:
            node.firstChild.nodeValue = "false"
        else:
            text_node = dom.createTextNode("false")
            node.appendChild(text_node)

        # write updated XML using toprettyxml(), decode string, remove blank lines
        xml_bytes = dom.toprettyxml(indent="  ", encoding="utf-8")
        xml_str = xml_bytes.decode("utf-8")
        xml_str = "\n".join([line for line in xml_str.splitlines() if line.strip() != ""])
        with open(config_path, "w", encoding="utf-8") as f:
              f.write(xml_str)
        print(f"[SUCCESS] Updated: {config_path}")
        print(f"[INFO] Backup at: {backup_path}")
        print("[INFO] Restart the servers for changes to take effect")
    except Exception as e:
        print(f"[ERROR] Failed to process {config_path}: {e}")
        if backup_path and os.path.exists(backup_path):
            print(f"[INFO] Backup available at: {backup_path}")
        sys.exit(2)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python update_secure_replication.py <config_path>")
        sys.exit(1)
    update_secure_replication(sys.argv[1])