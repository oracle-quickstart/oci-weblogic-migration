# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

'''
Usage
-----

This script must be run in the **OCI Cloud Shell** after the WebLogic migration or environment
setup has completed, and **before running `terraform destroy`**.

It performs cleanup of temporary networking resources that may have been created by:
    - `open_db_port.py`  → Security Lists for database access
    - `vcn_peering.py`   → Route Table rules for VCN peering

Specifically, this script:
    1. Removes temporary ingress rules from DB subnets.
    2. Removes peering route rules between WebLogic and DB subnets.
    3. Deletes the custom security lists associated with those rules.

Parameters
----------
--db-subnet-id    : OCID of the Database subnet
--wls-subnet-id   : OCID of the WebLogic subnet

Example
-------
Run the following command inside Cloud Shell:

    python3 cleanup_network_resources.py \
        --db-subnet-id ocid1.subnet.oc1.iad.aaaa...abcd \
        --wls-subnet-id ocid1.subnet.oc1.iad.aaaa...wxyz

'''

import oci
import sys
import json
import traceback
import argparse
from oci.exceptions import ServiceError

config = oci.config.from_file()
core_client = oci.core.VirtualNetworkClient(config)
virtual_network_composite_operations = oci.core.VirtualNetworkClientCompositeOperations(core_client)

def get_lpg_ids(subnet, suffix):
    """
    Fetch a list of Local Peering Gateways (LPGs) in the same VCN as the given subnet
    whose display name contains the specified suffix.
    """
    compartment_id = subnet.compartment_id
    vcn_id = subnet.vcn_id

    try:
        response = core_client.list_local_peering_gateways(compartment_id=compartment_id,vcn_id=vcn_id)

        #  Filter LPGs whose display-name contains the suffix
        lpg_ids = [
            lpg.id for lpg in response.data
            if suffix in lpg.display_name
        ]

        if not lpg_ids:
            print(f"No LPGs found in VCN {subnet.vcn_id} containing '{suffix}' in name.")

        return lpg_ids

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied. Please check the IAM policies required for Network Access")
            print(f"{str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while getting Local Peering Gateways details in vcn id {vcn_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while fetching Local Peering Gateways in vcn id {vcn_id}: {str(e)}")
        sys.exit(1)



def get_seclist_details(seclist_id):
    """
    Fetch Security List details.
    """
    try:
        get_security_list_response = core_client.get_security_list(security_list_id=seclist_id)
        return get_security_list_response.data

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied. Please check the IAM policies required for Network Access")
            print(f"{str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while getting Security List details. Security List {seclist_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while fetching security list {seclist_id}: {str(e)}")
        sys.exit(1)

def get_subnet_details(subnet_id):
    """
    Fetch Subnet details.
    """
    try:
        get_subnet_response = core_client.get_subnet(subnet_id=subnet_id)
        return(get_subnet_response.data)

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Policy missing for the following request. Please check the IAM Network policies required. Add the missing policy and then run the script again.")
            print(f"{str(e)}")
            sys.exit(1)
        else:
            print(f"{str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"{str(e)}")
        sys.exit(1)

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
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied. Please check the IAM policies required for Network Access")
            print(f"{str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while updating subnet {subnet_id}: {str(e)}")
            sys.exit(1)
    except Exception as e:
        print(f"Unexpected error while updating subnet {subnet_id}: {str(e)}")
        sys.exit(1)

def remove_route_rule(route_table_id, destination_cidr, target_id):
    """
    Removes a specific route rule from the route table if it exists.

    Internally, this function retrieves the existing route rules and rebuilds
    the list excluding the rule that matches the given destination CIDR and
    target network entity (i.e., keeps all other rules intact).
    """
    try:
        get_route_table_response = core_client.get_route_table(rt_id=route_table_id)
        route_rules = [
            rule for rule in get_route_table_response.data.route_rules
            if not (rule.destination == destination_cidr and rule.network_entity_id == target_id)
        ]

        if len(route_rules) == len(get_route_table_response.data.route_rules):
            print(f"No matching route rule found for destination {destination_cidr} via {target_id} in route table {route_table_id}")
            return

        core_client.update_route_table(
            rt_id=route_table_id,
            update_route_table_details=oci.core.models.UpdateRouteTableDetails(route_rules=route_rules)
        )
        print(f"Removed route to {destination_cidr} via {target_id} in route table {route_table_id}")

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied. Please check the IAM policies required for Network Access")
            print(f"{str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while removing route rule from the route table {route_table_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Failed to remove route rule in {route_table_id}: {str(e)}")
        sys.exit(1)

def cleanup_route_rules(db_subnet, wls_subnet):
    """
     Cleans up route table rules.
    """
    print("Cleaning up Route Rules...")

    wls_rt_id = wls_subnet.route_table_id
    wls_cidr = wls_subnet.cidr_block

    db_rt_id = db_subnet.route_table_id
    db_cidr = db_subnet.cidr_block

    wls_display_name = wls_subnet.display_name
    suffix=(wls_display_name.split('-')[1] if '-' in wls_display_name else "")

    wls_lpg_ids = get_lpg_ids(subnet=wls_subnet, suffix=suffix)
    db_lpg_ids = get_lpg_ids(subnet=db_subnet, suffix=suffix)

    # Remove route rules
    for wls_lpg_id in wls_lpg_ids:
        remove_route_rule(wls_rt_id, db_cidr, wls_lpg_id)

    for db_lpg_id in db_lpg_ids:
        remove_route_rule(db_rt_id, wls_cidr, db_lpg_id)


def cleanup_security_lists(db_subnet, wls_subnet):
    """
    Deletes any security list created by open_db_port.py
    and detaches them from subnets.
    """
    print("Cleaning up security list...")

    wls_display_name = wls_subnet.display_name
    seclist_suffix=(wls_display_name.split('-')[1] if '-' in wls_display_name else "")
    seclist_ids = db_subnet.security_list_ids

    # Identify all security lists to remove for this subnet
    seclists_to_delete = []
    for seclist_id in seclist_ids:
        seclist = get_seclist_details(seclist_id)
        if seclist_suffix in seclist.display_name:
            seclists_to_delete.append(seclist)

    if not seclists_to_delete:
        print(f"No security lists to delete in db subnet: {db_subnet.id}")
        return

    #Removing the targeted Security List(s) from the list of Security Lists of the subnet.
    target_ids = [s.id for s in seclists_to_delete]
    updated_lists = [sid for sid in seclist_ids if sid not in target_ids]
    update_subnet_details(db_subnet.id, "security_list_ids", updated_lists)

    for seclist in seclists_to_delete:
        print(f"Removing security list: {seclist.display_name} from subnet: {db_subnet.display_name}")
        # Deleting the security list
        try:
            core_client.delete_security_list(security_list_id=seclist.id)
            print(f"    Deleted Security List: {seclist.display_name}")

        except ServiceError as e:
            if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
                print("Resource not found or access denied. Please check the IAM policies required for Network Access")
                print(f"{str(e)}")
                sys.exit(1)
            else:
                print(f"Service error while deleting Security list {seclist.id}: {str(e)}")
                sys.exit(1)

        except Exception as e:
            print(f"Unexpected error while updating security list {seclist.display_name}: {str(e)}")
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Cleanup OCI network resources")
    parser.add_argument("--db-subnet-id", required=True, help="OCID of the DB subnet")
    parser.add_argument("--wls-subnet-id", required=True, help="OCID of the WebLogic subnet")
    args = parser.parse_args()

    db_subnet_id = args.db_subnet_id
    wls_subnet_id = args.wls_subnet_id

    wls_subnet = get_subnet_details(wls_subnet_id)
    db_subnet = get_subnet_details(db_subnet_id)

    cleanup_security_lists(db_subnet, wls_subnet)
    cleanup_route_rules(db_subnet, wls_subnet)

if __name__ == "__main__":
    try:
        main()
        print("Cleanup complete. You can now safely run 'terraform destroy'.")
    except Exception as e:
        print(f"Cleanup failed: {str(e)}")
        traceback.print_exc()
        sys.exit(1)