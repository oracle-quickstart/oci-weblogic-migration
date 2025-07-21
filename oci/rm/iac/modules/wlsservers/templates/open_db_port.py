# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

"""
Opens DB port on DB subnet.
Enables incoming requests from WLS subnet on port DB port to the DB subnet,
"""

import sys
import oci
import oci.core.models.tcp_options as tcp_options
from oci.core.models import port_range, update_subnet_details, egress_security_rule, ingress_security_rule, create_security_list_details

from restore_archives import get_attribute
from vcn_peering import get_subnet_details, get_wls_subnet_id, get_db_subnet_id

def get_db_existing_vcn_id():
    return get_attribute("db_existing_vcn_id")


def open_db_port(db_port=1521, db_vcn_compartment_id=None, db_vcn_id=None, db_subnet_id=None,
                 wls_subnet_cidr=None):
    """
    This method creates a new security list with same service prefix as the instance,
    it enable incoming requests from WLS subnet on port <db port> to the DB subnet, and it also allow traffic from DB
    subnet to the WLS subnet on port <db port>
    :param service_prefix: The service instance prefix
    :param db_port: The db port, defaulted to 1521
    :param db_vcn_compartment_id: The DB vcn compartment ocid
    :param db_vcn_id: The DB vcn ocid
    :param db_subnet_id: The DB subnet ocid
    :param wls_subnet_cidr: The WLS subnet CIDR
    """

    principal = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
    network_client = oci.core.VirtualNetworkClient(config={}, signer=principal)

    display_name = "wls-to-db-seclist"
    db_port_range = port_range.PortRange(max=db_port, min=db_port)
    tcp = tcp_options.TcpOptions(destination_port_range=db_port_range)
    ingres_rules = []
    egres_rules = []
    ingress = ingress_security_rule.IngressSecurityRule(is_stateless=False,
                                                        source=wls_subnet_cidr,
                                                        tcp_options=tcp,
                                                        protocol="6",
                                                        description="Allow ingress traffic from WLS subnet on DB port")
    ingres_rules.append(ingress)
    seclist_details = create_security_list_details.CreateSecurityListDetails(compartment_id=db_vcn_compartment_id,
                                                                             display_name=display_name,
                                                                             egress_security_rules=egres_rules,
                                                                             ingress_security_rules=ingres_rules,
                                                                             vcn_id=db_vcn_id)
    try:
        security_list_ids = network_client.get_subnet(subnet_id=db_subnet_id).data.security_list_ids
        if len(security_list_ids) == 5:
            print(f"Error: Subnet security list limit reached. 5 security lists {security_list_ids} are already associated with the DB subnet {db_subnet_id} and a new security list cannot be added.")
            raise Exception("Unable to add security list for opening DB port, as DB subnet has 5 security lists which is the maximum permissible limit")
        else:
            seclist_ocid = network_client.create_security_list(create_security_list_details=seclist_details).data.id
            print(f"Successfully created security list: {seclist_ocid}")
            security_list_ids.append(seclist_ocid)
            subnet_details = update_subnet_details.UpdateSubnetDetails(security_list_ids=security_list_ids)
            network_client.update_subnet(subnet_id=db_subnet_id, update_subnet_details=subnet_details)
            print(f"Successfully added security list {seclist_ocid} to subnet {db_subnet_id}")

    except Exception as e:
        print(f"Failed to open DB port. {str(e)}")
        raise Exception("Unable to open DB port using security list")


if __name__ == '__main__':

    if len(sys.argv) < 5:
        print(f"usage: {sys.argv[0]} <db_port> <db_vcn_compartment_id> <db_vcn_id> <db_subnet_id>", file=sys.stderr)
        sys.exit(1)

    wls_subnet = get_subnet_details(get_wls_subnet_id())
    wls_subnet_cidr_block = wls_subnet.cidr_block
    # db_existing_vcn_id = get_db_existing_vcn_id()
    # db_subnet_id = get_db_subnet_id()
    # db_subnet = get_subnet_details(db_subnet_id)
    # db_vcn_compartment_id = db_subnet.compartment_id

    db_port = sys.argv[1]
    db_vcn_compartment_id=sys.argv[2]
    db_vcn_id=sys.argv[3]
    db_subnet_id=sys.argv[4]


    open_db_port(
        db_port=db_port,
        db_vcn_compartment_id=db_vcn_compartment_id,
        db_vcn_id=db_vcn_id,
        db_subnet_id=db_subnet_id,
        wls_subnet_cidr=wls_subnet_cidr_block
    )


