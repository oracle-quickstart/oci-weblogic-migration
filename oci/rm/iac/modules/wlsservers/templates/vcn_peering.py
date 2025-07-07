# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

"""
Establishes peering connection between Weblogic and Database VCNs' LPGs
Updates the Weblogic and Database subnet route tables for VCN peering.
"""

import oci
import sys
from restore_archives import getAttribute

# Initialize service clients
principal = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
database_client = oci.database.DatabaseClient(config={}, signer=principal)
core_client = oci.core.VirtualNetworkClient(config={}, signer=principal)
virtual_network_composite_operations = oci.core.VirtualNetworkClientCompositeOperations(core_client)

def get_db_subnet_id():
    return getAttribute("db_subnet_id")

def get_db_lpg_id():
    return getAttribute("db_lpg")

def get_wls_subnet_id():
    return getAttribute("wlsserver_subnet_id")

def get_wls_lpg_id():
    return getAttribute("wlsserver_lpg")

def get_subnet_details(subnet_id):
    get_subnet_response = core_client.get_subnet(subnet_id=subnet_id)
    return(get_subnet_response.data)

def establish_peering_between_lpgs():
    """
    Establishes peering connection between LPGs
    """
    try:
        wls_lpg_id = get_wls_lpg_id()
        db_lpg_id = get_db_lpg_id()
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
    wls_subnet = get_subnet_details(get_wls_subnet_id())
    wls_rt_id = wls_subnet.route_table_id
    wls_lpg_id = get_wls_lpg_id()
    wls_subnet_cidr_block = wls_subnet.cidr_block
    db_subnet = get_subnet_details(get_db_subnet_id())
    db_rt_id = db_subnet.route_table_id
    db_lpg_id = get_db_lpg_id()
    db_subnet_cidr_block = db_subnet.cidr_block

    #Establish peering connection between LPGs of weblogic and database VCNs
    result = establish_peering_between_lpgs()

    #Add a route to the current route table of the weblogic subnet to direct traffic
    #to the CIDR of the Database subnet to the LPG.
    add_route_rule_to_route_table(wls_rt_id, db_subnet_cidr_block, wls_lpg_id)

    #Add a route to the current route table of the database subnet to direct traffic
    #to the CIDR of the WebLogic subnet to the LPG.
    add_route_rule_to_route_table(db_rt_id, wls_subnet_cidr_block, db_lpg_id)
