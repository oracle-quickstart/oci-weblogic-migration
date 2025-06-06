# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

"""Updates the Weblogic and Database subnet route tables for VCN peering."""

import oci
import sys
import urllib.request, urllib.error, urllib.parse

# Initialize service clients
principal = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
database_client = oci.database.DatabaseClient(config={}, signer=principal)
core_client = oci.core.VirtualNetworkClient(config={}, signer=principal)
virtual_network_composite_operations = oci.core.VirtualNetworkClientCompositeOperations(core_client)

# Get metadata attribute.
def getAttribute(attribute, default=None):
    """
    Returns attribute or default value if no value is found
    """
    try:
        request_headers = {
            "Authorization": "Bearer Oracle"
        }
        request = urllib.request.Request("http://169.254.169.254/opc/v2/instance/metadata/" + attribute,
                                         headers=request_headers)
        result = urllib.request.urlopen(request).read()
        return result.decode("utf-8")
    except urllib.error.HTTPError as er:
        logger.debug("0009", attribute, str(er))
        pass
    except Exception as ex:
        logger.debug("0008", attribute, str(ex))
        pass

    return default

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

def add_route_rule_to_route_table(route_table_id, cidr_block, lpg_id):
    """
        Adds a route rule to an existing route table.
        :param route_table_id: route table to be updated
        :param cidr_block: destination cidr_block
        :param lpg_id: local peering gateway OCID
    """

    try:
        get_route_table_response = core_client.get_route_table(rt_id=route_table_id)
        route_rules = get_route_table_response.data.route_rules
        route_rule = oci.core.models.RouteRule(
            cidr_block=None,
            destination=cidr_block,
            destination_type='CIDR_BLOCK',
            network_entity_id=lpg_id
        )
        route_rules.append(route_rule)
        update_route_table_details = oci.core.models.UpdateRouteTableDetails(route_rules=route_rules)
        update_route_table_response = virtual_network_composite_operations.update_route_table_and_wait_for_state(
            route_table_id,
            update_route_table_details,
            wait_for_states=[oci.core.models.RouteTable.LIFECYCLE_STATE_AVAILABLE]
        )
        route_table = update_route_table_response.data
    except Exception as e:
        print(e)
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
    #Add a route to the current route table of the weblogic subnet to direct traffic
    #to the CIDR of the Database subnet to the LPG.
    add_route_rule_to_route_table(wls_rt_id, db_subnet_cidr_block, wls_lpg_id)

    #Add a route to the current route table of the database subnet to direct traffic
    #to the CIDR of the WebLogic subnet to the LPG.
    add_route_rule_to_route_table(db_rt_id, wls_subnet_cidr_block, db_lpg_id)

    sys.exit(0)
