# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

#!/usr/bin/env python3

import oci
import argparse
import sys

signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
network_client = oci.core.VirtualNetworkClient(config={}, signer=signer)


def get_subnet(subnet_id):
    """
    Returns subnet object or exits with error if unauthorized or not found
    """
    try:
        response = network_client.get_subnet(subnet_id=subnet_id)
        return response.data
    except oci.exceptions.ServiceError as e:
        if e.status == 404 or e.status == 403:
            print(f"[ERROR] Failed to access subnet {subnet_id}: {e.message}")
        else:
            print(f"[ERROR] OCI ServiceError: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}")
        sys.exit(1)

def attach_security_list(subnet_id, new_seclist_id):
    """
    Attaches the new security list to the subnet if not already attached
    """
    subnet = get_subnet(subnet_id)
    existing_ids = subnet.security_list_ids or []

    if new_seclist_id in existing_ids:
        print(f"[INFO] Security list {new_seclist_id} already attached to subnet {subnet_id}")
        return

    updated_ids = existing_ids + [new_seclist_id]
    update_details = oci.core.models.UpdateSubnetDetails(security_list_ids=updated_ids)

    try:
        network_client.update_subnet(subnet_id=subnet_id, update_subnet_details=update_details)
        print(f"[SUCCESS] Attached new security list {new_seclist_id} to subnet {subnet_id}")
    except oci.exceptions.ServiceError as e:
        print(f"[ERROR] Failed to update subnet: {e.message}")
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--db_subnet_id", required=True, help="OCID of the DB subnet")
    parser.add_argument("--new_seclist_id", required=True, help="OCID of the new security list to attach")
    args = parser.parse_args()

    attach_security_list(args.db_subnet_id, args.new_seclist_id)