# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

"""
Establishes peering connection between Weblogic and Database VCNs' LPGs
Updates the Weblogic and Database subnet route tables for VCN peering.
"""

import oci
import sys
import json
from restore_archives import get_attribute

# Initialize service clients
principal = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
database_client = oci.database.DatabaseClient(config={}, signer=principal)
core_client = oci.core.VirtualNetworkClient(config={}, signer=principal)
virtual_network_composite_operations = oci.core.VirtualNetworkClientCompositeOperations(core_client)

def get_db_subnet_map():
     return get_attribute("db_subnet_ids")

def get_db_lpg_map():
    return get_attribute("db_lpg_ids")

def get_wls_subnet_id():
    return get_attribute("wlsserver_subnet_id")

def get_wls_lpg_map():
    return get_attribute("wlsserver_lpg_ids")

def get_subnet_details(subnet_id):
    get_subnet_response = core_client.get_subnet(subnet_id=subnet_id)
    return(get_subnet_response.data)

def establish_peering_between_lpgs(wls_lpg_id, db_lpg_id):
    """
    Establishes peering connection between LPGs
    """
    try:
        connect_local_peering_gateways_response = core_client.connect_local_peering_gateways(
            local_peering_gateway_id=wls_lpg_id,
            connect_local_peering_gateways_details=oci.core.models.ConnectLocalPeeringGatewaysDetails(
                peer_id=db_lpg_id))
        print(f"Peering established between LPGs : {wls_lpg_id} and {db_lpg_id}")
    except Exception as e:
        if e.status == 400 and e.target_service == 'virtual_network' and e.operation_name == 'connect_local_peering_gateways' and "has already been established" in str(e):
            print(f"{e.message}")
            pass
        else:
            print(f"Error: {e}")
            sys.exit(-1)

def add_route_rule_to_route_table(route_table_id, destination_cidr, target_id):
    """
    Checks if a specific route rule exists in an OCI route table.
    If not, adds the route rule to an OCI route table.

    Args:
        route_table_id (str): The OCID of the route table to check.
        destination_cidr (str): The destination CIDR block of the route rule.
        target_id (str): The OCID of the local peering gateway.

    """

    try:
        get_route_table_response = core_client.get_route_table(rt_id=route_table_id)
        route_rules = get_route_table_response.data.route_rules
        for rule in route_rules:
            if rule.destination == destination_cidr and rule.destination_type == 'CIDR_BLOCK' and rule.network_entity_id == target_id:
                print(f"Route rule already exists in route table {route_table_id}  : Skipping....")
                return

        route_rule = oci.core.models.RouteRule(
            cidr_block=None,
            destination=destination_cidr,
            destination_type='CIDR_BLOCK',
            network_entity_id=target_id
        )
        route_rules.append(route_rule)
        update_route_table_details = oci.core.models.UpdateRouteTableDetails(route_rules=route_rules)
        update_route_table_response = virtual_network_composite_operations.update_route_table_and_wait_for_state(
            route_table_id,
            update_route_table_details,
            wait_for_states=[oci.core.models.RouteTable.LIFECYCLE_STATE_AVAILABLE]
        )
        route_table = update_route_table_response.data
        print(f"Route rule added to route table {route_table_id}")
    except Exception as e:
        print(f"Error: {e.message}")
        sys.exit(-1)

if __name__ == '__main__':
    wlsserver_lpg_ids_list = json.loads(get_wls_lpg_map())
    db_lpg_ids_list = json.loads(get_db_lpg_map())

    # Extract the actual maps from the single-element lists
    wlsserver_lpg_ids = wlsserver_lpg_ids_list[0]
    db_lpg_ids  = db_lpg_ids_list[0]

    db_subnet_ids = json.loads(get_db_subnet_map())
    wls_subnet = get_subnet_details(get_wls_subnet_id())
    wls_rt_id = wls_subnet.route_table_id
    wls_subnet_cidr_block = wls_subnet.cidr_block

    #Get sets of non-null keys
    wls_lpg_keys = {k for k, v in wlsserver_lpg_ids.items() if v is not None}
    db_lpg_keys = {k for k, v in db_lpg_ids.items() if v is not None}
    subnet_keys = {k for k, v in db_subnet_ids.items() if v is not None}

    #Compare lengths and keys
    if len(wls_lpg_keys) == len(db_lpg_keys) == len(subnet_keys):
        if wls_lpg_keys == db_lpg_keys == subnet_keys:
            print(f"All three maps {wlsserver_lpg_ids} ,{db_lpg_ids} and {db_subnet_ids} have {len(wls_lpg_keys)} non-null entries at the same keys: {sorted(wls_lpg_keys)}")
        else:
            raise ValueError("Non-null entries are at different keys across maps.")
    else:
        raise ValueError("Maps do not have equal numbers of non-null entries.")

    #Execute loop for only the matching non-null keys
    for key in sorted(wls_lpg_keys):
        wls_lpg_id = wlsserver_lpg_ids[key]
        db_lpg_id = db_lpg_ids[key]
        db_subnet_id = db_subnet_ids[key]
        db_subnet = get_subnet_details(db_subnet_id)
        db_rt_id = db_subnet.route_table_id
        db_subnet_cidr_block = db_subnet.cidr_block

        #Establish peering connection between LPGs of weblogic and database VCNs
        print(f" Establishing peering between WLS LPG: {wls_lpg_id} and DB LPG: {db_lpg_id}")
        result = establish_peering_between_lpgs(wls_lpg_id, db_lpg_id)

        #Add a route to the current route table of the weblogic subnet to direct traffic
        #to the CIDR of the Database subnet to the LPG.
        print(f"Adding a route to weblogic subnet route table {wls_rt_id} for the CIDR of the Database subnet {db_subnet_cidr_block} to the WLS LPG {wls_lpg_id}")
        add_route_rule_to_route_table(wls_rt_id, db_subnet_cidr_block, wls_lpg_id)

        #Add a route to the current route table of the database subnet to direct traffic
        #to the CIDR of the WebLogic subnet to the LPG.
        print(f"Adding a route to database subnet route table {db_rt_id} for the CIDR of the Weblogic subnet {wls_subnet_cidr_block} to the WLS LPG {db_lpg_id}")
        add_route_rule_to_route_table(db_rt_id, wls_subnet_cidr_block, db_lpg_id)
