# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

'''
Cleanup script for custom OCI resources created by:
    - open_db_port.py (security lists)
    - vcn_peering.py (route table rules)
'''

import oci
import sys
import json
from oci.exceptions import ServiceError

from restore_archives import get_attribute
from vcn_peering import (
    get_subnet_details,
    get_wls_subnet_id,
    get_db_subnet_map,
    get_db_lpg_map,
    get_wls_lpg_map,
)

# Initialize service clients.
principal = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
core_client = oci.core.VirtualNetworkClient(config={}, signer=principal)
virtual_network_composite_operations = oci.core.VirtualNetworkClientCompositeOperations(core_client)


def get_seclist_details(seclist_id):
    """
    Fetch Security List details.
    """
    try:
        get_security_list_response = core_client.get_security_list(security_list_id=seclist_id)
        return get_security_list_response.data

    except ServiceError as e:
        raise Exception(f"ServiceError while fetching security list {seclist_id}: {e.message}")

    except Exception as e:
        raise Exception(f"Unexpected error while fetching security list {seclist_id}: {str(e)}")

def update_subnet_details(subnet_id, field_name, field_value):
    """
    Updates a specific field of a subnet (e.g., security_list_ids).
    """
    try:
        update_args = {field_name: field_value}
        core_client.update_subnet(
            subnet_id=subnet_id,
            update_subnet_details=oci.core.models.UpdateSubnetDetails(**update_args)
        )
        print(f"Updated subnet {subnet_id}: set {field_name} = {field_value}")
    except ServiceError as e:
        raise Exception(f"Service error while updating subnet {subnet_id}: {e.message}")
    except Exception as e:
        raise Exception(f"Unexpected error while updating subnet {subnet_id}: {str(e)}")

def remove_route_rule(route_table_id, destination_cidr, target_id):
    """
    Remove route rule if exists.
    """
    try:
        get_route_table_response = core_client.get_route_table(rt_id=route_table_id)
        route_rules = [
            rule for rule in get_route_table_response.data.route_rules
            if not (rule.destination == destination_cidr and rule.network_entity_id == target_id)
        ]
        core_client.update_route_table(
            rt_id=route_table_id,
            update_route_table_details=oci.core.models.UpdateRouteTableDetails(route_rules=route_rules)
        )
        print(f"Removed route to {destination_cidr} via {target_id} in route table {route_table_id}")
    except Exception as e:
        print(f"Failed to remove route rule in {route_table_id}: {str(e)}")


def cleanup_security_lists():
    """
    Deletes any security list created by open_db_port.py
    and detaches them from subnets.
    """
    print("Cleaning up security list...")

    # Loads DB subnet OCIDs from Terraform-generated metadata
    db_subnet_ids = json.loads(get_db_subnet_map())[0]
    wls_subnet = get_subnet_details(get_wls_subnet_id())
    wls_display_name = wls_subnet.display_name
    seclist_suffix=(wls_display_name.split('-')[1] if '-' in wls_display_name else "")

    for key, db_subnet_id in db_subnet_ids.items():
        if not db_subnet_id:
            continue
        subnet = get_subnet_details(db_subnet_id)
        seclist_ids = subnet.security_list_ids

        # Identify all security lists to remove for this subnet
        seclists_to_delete = []
        for seclist_id in seclist_ids:
            seclist = get_seclist_details(seclist_id)
            if seclist_suffix in seclist.display_name:
                seclists_to_delete.append(seclist)

        if not seclists_to_delete:
            continue

        #Removing the targeted Security List(s) from the list of Security Lists of the subnet.
        target_ids = [s.id for s in seclists_to_delete]
        updated_lists = [sid for sid in seclist_ids if sid not in target_ids]
        update_subnet_details(subnet.id, "security_list_ids", updated_lists)

        for seclist in seclists_to_delete:
            print(f"Removing security list: {seclist.display_name} from subnet: {subnet.display_name}")
            # Deleting the security list
            try:
                core_client.delete_security_list(security_list_id=seclist.id)
                print(f"    Deleted Security List: {seclist.display_name}")
            except ServiceError as e:
                print(f"    Failed to delete {seclist.display_name}: {e.message}")
            except Exception as e:
                print(f"Unexpected error while updating security list {seclist.display_name}: {str(e)}")


def cleanup_route_rules():
    """
     Cleans up route table rules.
    """
    print("Cleaning up Route Rules...")

    wlsserver_lpg_ids = json.loads(get_wls_lpg_map())[0]
    db_lpg_ids = json.loads(get_db_lpg_map())[0]
    db_subnet_ids = json.loads(get_db_subnet_map())[0]

    wls_subnet = get_subnet_details(get_wls_subnet_id())
    wls_rt_id = wls_subnet.route_table_id
    wls_cidr = wls_subnet.cidr_block

    for key in sorted(wlsserver_lpg_ids):
        wls_lpg_id = wlsserver_lpg_ids[key]
        db_lpg_id = db_lpg_map.get(key)
        db_subnet_id = db_subnet_map.get(key)

        if not all([wls_lpg_id, db_lpg_id, db_subnet_id]):
            continue

        db_subnet = get_subnet_details(db_subnet_id)
        db_rt_id = db_subnet.route_table_id
        db_cidr = db_subnet.cidr_block

        # Remove route rules
        remove_route_rule(wls_rt_id, db_cidr, wls_lpg_id)
        remove_route_rule(db_rt_id, wls_cidr, db_lpg_id)

if __name__ == "__main__":
    try:
        cleanup_security_lists()
        cleanup_route_rules()
        print("Cleanup complete. You can now safely run 'terraform destroy'.")
    except Exception as e:
        print(f"Cleanup failed: {str(e)}")
        sys.exit(1)