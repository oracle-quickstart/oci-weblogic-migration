# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

'''
Usage
-----

This script must be run in the **OCI Cloud Shell** .

It performs cleanup of temporary networking resources that may have been created by:
    - `open_db_port.py`  → Security Lists for database access
    - `vcn_peering.py`   → Route Table rules for VCN peering

Specifically, this script:
    1. Removes temporary ingress rules from DB subnets.
    2. Removes peering route rules between WebLogic and DB subnets.
    3. Deletes the custom security lists associated with those rules.

Parameters
----------
--stack-id    : OCID of the stack

Example
-------
Run the following command inside Cloud Shell:

    python3 test_cleanup_with_stack_id.py --stack-id ocid1.ormstack.oc1.iad.amaa...xyz

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
resource_manager_client = oci.resource_manager.ResourceManagerClient(config)
compute_client = oci.core.ComputeClient(config)
db_client = oci.database.DatabaseClient(config)


def get_latest_successful_job(stack_id):
    """
    Returns the most recent SUCCESSFUL job for the given stack_id.
    """
    try:
        response = resource_manager_client.list_jobs(stack_id=stack_id, sort_by="TIMECREATED", sort_order="DESC", lifecycle_state="SUCCEEDED")
        successful_jobs = response.data

        if not successful_jobs:
            print(f"No successful jobs found for stack {stack_id}")
            return None

        return successful_jobs[0]

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied. Please check the IAM policies required for Network Access")
            print(f"{str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while getting latest successful Jobs details in stack id {stack_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while fetching latest successful Jobs details in stack id {stack_id}: {str(e)}")
        sys.exit(1)

def get_tf_output_value(job_id):
    """
    Fetches the 'resource_identifier_value' output from a Resource Manager job's Terraform state.

    Args:
       job_id (str): The OCID of the Resource Manager job.

    Returns:
       str: The value of 'resource_identifier_value' if found, otherwise None.
   """

    try:
        #Fetch Terraform state JSON for the given job
        response = resource_manager_client.get_job_tf_state(job_id=job_id)
        state_json = json.loads(response.data.text)

        #Extract the output value
        outputs = state_json.get("outputs", {})
        identifier_output = outputs.get("resource_identifier_value")

        if not identifier_output:
            print(f"'resource_identifier_value' not found in job {job_id}")
            return None

        value = identifier_output.get("value")
        return value

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied. Please check IAM permissions for Resource Manager.")
            print(f"Details: {str(e)}")
        else:
            print(f"Service error while fetching Terraform output for job {job_id}: {str(e)}")
        sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while reading job Terraform state for {job_id}: {str(e)}")
        sys.exit(1)

def get_stack_data_variables(stack_id):
    """
    Fetches stack's data variables.
    """
    try:
        # Get stack details
        response = resource_manager_client.get_stack(stack_id=stack_id)
        data_variables = response.data.variables

        if data_variables:
            return data_variables
        else:
            return None

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied. Error occurred while while fetching stack data variables. Please verify your IAM permissions for Resource Manager.")
            print(f"Details: {str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while fetching stack variables for stack {stack_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while fetching stack data variables for stack {stack_id}: {str(e)}")
        sys.exit(1)

def get_db_ids_from_stack(data_variables):
    """
    Fetches all database OCIDs (ATP and OCI DB Systems) from a given stack's variables.

    Returns:
        list: A combined list of database OCIDs.
    """
    # Get stack details
    db_ocids = []

    # Collect all database IDs dynamically
    for key, value in data_variables.items():
        if key.startswith("atp_db_id_") or key.startswith("oci_db_dbsystem_id_"):
            db_ocids.append(value)
    return db_ocids

def get_atp_subnet_id(atp_id):
    """
    Fetches the subnet OCID for a given Autonomous Database (ATP).

    Returns:
        str: Subnet OCID if exists, otherwise None.
    """
    try:
        response = db_client.get_autonomous_database(autonomous_database_id=atp_id)
        subnet_id = getattr(response.data, "subnet_id", None)
        return subnet_id
    except ServiceError as e:
        if e.status == 404 and e.code == "NotAuthorizedOrNotFound":
            print("Resource not found or access denied while fetching ATP subnet.")
            print(f"Details: {str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while fetching subnet for ATP database {atp_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while retrieving subnet for ATP database {atp_id}: {str(e)}")
        sys.exit(1)

def get_dbsystem_subnet_id(db_id):
    """
    Fetches the subnet OCID for a given OCI DB System.

    Returns:
        str: Subnet OCID if exists, otherwise None.
    """
    try:
        response = db_client.get_db_system(db_system_id=db_id)
        subnet_id = getattr(response.data, "subnet_id", None)
        return subnet_id

    except ServiceError as e:
        if e.status == 404 and e.code == "NotAuthorizedOrNotFound":
            print("Resource not found or access denied while fetching OCI DB System subnet.")
            print(f"Details: {str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while fetching subnet for OCI DB System {db_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while retrieving subnet for OCI DB System {db_id}: {str(e)}")
        sys.exit(1)

def get_db_subnet_ids(db_ids):
    '''
        Calls get_atp_subnet_id() if the db_id contains ".autonomousdatabase", i.e, a ATP DB.
        Calls get_atp_subnet_id() if the db_id contains ".dbsystem", i.e, a OCI DB.
    '''
    db_subnet_ids = []

    for db_id in db_ids:
        if ".autonomousdatabase." in db_id:
            subnet_id = get_atp_subnet_id(atp_id=db_id)
        elif ".dbsystem." in db_id:
            subnet_id = get_dbsystem_subnet_id(db_id=db_id)
        else:
            continue

        if subnet_id is not None:
            db_subnet_ids.append(subnet_id)

    return db_subnet_ids

def get_route_table_ids(compartment_id, vcn_id):
    """
    Fetches and returns a list of all Route Table OCIDs within the specified VCN.

    Parameters:
        compartment_id (str): The OCID of the compartment
        vcn_id (str): The OCID of the VCN

    Returns:
        list: A list of route table OCIDs found in the VCN. Otherwise, None.
    """
    try:
        response = core_client.list_route_tables(
            compartment_id=compartment_id,
            vcn_id=vcn_id
        )
        route_tables = response.data

        if not route_tables:
            print(f"No route tables found in VCN {vcn_id}")
            return None

        route_table_ids = [rt.id for rt in route_tables]
        return route_table_ids

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied while fetching Route Table details. Please check the IAM policies required for Network Access.")
            print(f"{str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while fetching Route Tables for VCN {vcn_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while fetching Route Tables for VCN {vcn_id}: {str(e)}")
        sys.exit(1)

def get_lpg_ids(compartment_id, vcn_id, suffix):
    """
    Fetch a list of Local Peering Gateways (LPGs) in the same VCN as the given subnet
    whose display name contains the specified suffix.
    """

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

def get_vcn_id_by_name(compartment_id, vcn_name):
    """
    Fetches the VCN OCID by matching its display name in the given compartment.
    Returns the VCN OCID if found, or None if not found.
    """
    try:
        response = core_client.list_vcns(compartment_id=compartment_id)
        for vcn in response.data:
            if vcn.display_name == vcn_name:
                return vcn.id

        print(f"No VCN found with name '{vcn_name}' in compartment {compartment_id}")
        return None

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied while listing VCNs. Please check the IAM policies required for Network Access.")
            print(f"{str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while fetching VCN ID for '{vcn_name}': {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Failed to get VCN ID for '{vcn_name}': {str(e)}")
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
            print(f"Service error while fetching subnet details with id: {subnet_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while fetching subnet with id: {subnet_id}: {str(e)}")
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

def cleanup_route_rules(db_subnet, wls_compartment_id, wls_vcn_id, wls_cidr, suffix):
    """
     Cleans up route table rules.
    """
    print("Cleaning up Route Rules...")

    db_rt_id = db_subnet.route_table_id
    db_cidr = db_subnet.cidr_block

    wls_rt_ids = get_route_table_ids(compartment_id=wls_compartment_id,vcn_id=wls_vcn_id);

    wls_lpg_ids = get_lpg_ids(compartment_id=wls_compartment_id, vcn_id=wls_vcn_id,  suffix=suffix)
    db_lpg_ids = get_lpg_ids(compartment_id=db_subnet.compartment_id, vcn_id=db_subnet.vcn_id, suffix=suffix)

    # Remove route rules
    for wls_rt_id in wls_rt_ids:
        for wls_lpg_id in wls_lpg_ids:
            remove_route_rule(wls_rt_id, db_cidr, wls_lpg_id)

    for db_lpg_id in db_lpg_ids:
        remove_route_rule(db_rt_id, wls_cidr, db_lpg_id)

def cleanup_security_lists(db_subnet, seclist_suffix):
    """
    Deletes any security list created by open_db_port.py
    and detaches them from subnets.
    """
    print(f"Cleaning up security lists from db_subnet : {db_subnet.id}")

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
    parser.add_argument("--stack-id", required=True, help="OCID of the Stack")
    args = parser.parse_args()

    stack_id = args.stack_id

    latest_successful_job = get_latest_successful_job(stack_id)
    if not latest_successful_job:
        print(f"No latest successful job found in the provided stack id; {stack_id}")
        sys.exit(1)

    latest_successful_job_id = latest_successful_job.id
    suffix= get_tf_output_value(latest_successful_job_id)
    if not suffix:
        sys.exit(1)

    stack_variables = get_stack_data_variables(stack_id)
    if not stack_variables:
        print(f"No stack found with stack_id : {stack_id}")
        sys.exit(1)

    compartment_id = stack_variables["network_compartment_id"]
    vcn_name = stack_variables["vcn_name"]
    wlsserver_subnet_cidr = stack_variables["wlsserver_subnet_cidr"]
    vcn_id = get_vcn_id_by_name(compartment_id, vcn_name)

    db_ids = get_db_ids_from_stack(stack_variables)
    if not db_ids:
        print(f"No database OCIDs found in stack {stack_id}.")
        sys.exit(1)

    db_subnet_ids = get_db_subnet_ids(db_ids)

    for db_subnet_id in db_subnet_ids:
        db_subnet = get_subnet_details(db_subnet_id)
        cleanup_security_lists(db_subnet, seclist_suffix=suffix)
        cleanup_route_rules(db_subnet, wls_compartment_id=compartment_id, wls_vcn_id=vcn_id, wls_cidr=wlsserver_subnet_cidr, suffix=suffix)

if __name__ == "__main__":
    try:
        main()
        print("Cleanup complete. You can now safely run 'terraform destroy'.")
    except Exception as e:
        print(f"Cleanup failed: {str(e)}")
        traceback.print_exc()
        sys.exit(1)