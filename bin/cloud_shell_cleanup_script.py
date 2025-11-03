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

def get_wls_instance_id_by_job_id(job_id):
    """
    Returns the first WebLogic instance OCID from the job outputs of the given job_id.
    This function:
    1. Calls the Resource Manager API to list all output variables from the given job.
    2. Searches for the output named 'weblogic_instances'.
    3. Parses the JSON string in that output to extract the first instance OCID.
    """
    try:
        response = resource_manager_client.list_job_outputs(job_id=job_id)
        job_outputs = response.data.items

        for job_item in job_outputs:
            if job_item.output_name == "weblogic_instances":
                # job_item.output_value is a JSON string
                weblogic_instance_data = json.loads(job_item.output_value)
                domain_vms = next(iter(weblogic_instance_data.values()))
                wls_instance_id = next(iter(domain_vms.keys()))   # get first OCID key
                return wls_instance_id

        return None

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Error: The specified resource could not be found or you do not have permission to access it.")
            print("Please verify that your IAM policies allow access to OCI Resource Manager and Compute resources.")
            print(f"Details: {str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while listing job outputs for job {job_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while parsing weblogic_instances for job {job_id}: {str(e)}")
        traceback.print_exc()
        sys.exit(1)

def get_db_ids_from_stack(stack_id):
    """
    Fetches all database OCIDs (ATP and OCI DB Systems) from a given stack's variables.

    Returns:
        list: A combined list of database OCIDs.
    """
    try:
        # Get stack details
        response = resource_manager_client.get_stack(stack_id=stack_id)
        data_variables = response.data.variables

        db_ocids = []

        # Collect all database IDs dynamically
        for key, value in data_variables.items():
            if key.startswith("atp_db_id_") or key.startswith("oci_db_dbsystem_id_"):
                db_ocids.append(value)
        return db_ocids

    except ServiceError as e:
        if e.status == 404 and e.code == 'NotAuthorizedOrNotFound':
            print("Resource not found or access denied. Please verify your IAM permissions for Resource Manager.")
            print(f"Details: {str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while fetching stack variables for stack {stack_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while parsing database OCIDs for stack {stack_id}: {str(e)}")
        sys.exit(1)

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

def get_subnet_from_instance_id(instance_id):
    """
     Fetches the subnet OCID for a given Compute instance.
        - First checks instance metadata for 'wlsserver_subnet_id' (used in WebLogic stacks).
        - Falls back to checking the instance's primary VNIC attachment if not found.

     Returns:
       str: Subnet OCID if found, otherwise None.
   """
    try:
        instance = compute_client.get_instance(instance_id).data
        metadata = instance.metadata

        # Step 2: Try to fetch from metadata (WLS case)
        subnet_id = metadata.get("wlsserver_subnet_id")
        if subnet_id:
            return subnet_id

        print(f"No 'wlsserver_subnet_id' found for instance {instance_id}. Falling back to VNIC lookup...")

        # Step 3: Fallback – fetch via VNIC attachment
        vnics = oci.pagination.list_call_get_all_results(
            compute_client.list_vnic_attachments,
            compartment_id=instance.compartment_id,
            instance_id=instance_id
        ).data

        if not vnics:
            print(f"No VNIC attachments found for instance {instance_id}.")
            return None

        # Step 4: Pick first (primary) VNIC
        primary_vnic = vnics[0]
        subnet_id = getattr(primary_vnic, "subnet_id", None)

        if subnet_id:
            return subnet_id
        else:
            print(f"No subnet OCID found for instance {instance_id}.")
            return None

    except ServiceError as e:
        if e.status == 404 and e.code == "NotAuthorizedOrNotFound":
            print("Resource not found or access denied while fetching subnet from instance.")
            print(f"Details: {str(e)}")
            sys.exit(1)
        else:
            print(f"Service error while fetching subnet for instance {instance_id}: {str(e)}")
            sys.exit(1)

    except Exception as e:
        print(f"Unexpected error while retrieving subnet for instance {instance_id}: {str(e)}")
        sys.exit(1)

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
    print(f"Cleaning up security lists from db_subnet : {db_subnet}")

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
    parser.add_argument("--stack-id", required=True, help="OCID of the Stack")
    args = parser.parse_args()

    stack_id = args.stack_id

    latest_successful_job = get_latest_successful_job(stack_id)
    if not latest_successful_job:
        print(f"No latest successful job found in the provided stack id; {stack_id}")
        sys.exit(1)

    latest_successful_job_id = latest_successful_job.id

    wls_instance_id = get_wls_instance_id_by_job_id(latest_successful_job_id)
    if not wls_instance_id:
        print(f"No WLS instance found in the provided stack id; {stack_id}")
        sys.exit(1)

    wls_subnet_id = get_subnet_from_instance_id(wls_instance_id)
    if not wls_subnet_id:
        sys.exit(1)

    wls_subnet = get_subnet_details(wls_subnet_id)

    db_ids = get_db_ids_from_stack(stack_id)
    if not db_ids:
        print(f"No database OCIDs found in stack {stack_id}.")
        sys.exit(1)

    db_subnet_ids = get_db_subnet_ids(db_ids)

    for db_subnet_id in db_subnet_ids:
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