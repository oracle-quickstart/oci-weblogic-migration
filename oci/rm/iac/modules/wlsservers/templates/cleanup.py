# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

'''
Cleanup script for custom OCI resources created by open_db_port.py and vcn_peering.py
'''

import oci
import sys
import json
from oci.exceptions import ServiceError

from restore_archives import get_attribute
from vcn_peering import get_subnet_details, get_wls_subnet_id

# Initialize service clients
principal = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
core_client = oci.core.VirtualNetworkClient(config={}, signer=principal)
virtual_network_composite_operations = oci.core.VirtualNetworkClientCompositeOperations(core_client)

def get_seclist_details(seclist_id):
    try:
        get_security_list_response = core_client.get_security_list(security_list_id=seclist_id)
        return(get_security_list_response.data)

    except ServiceError as e:
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
        print(f"Service error while updating subnet {subnet_id}: {str(e)}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error while updating subnet {subnet_id}: {str(e)}")
        sys.exit(1)

def cleanup_security_lists():
    """
    Deletes any security list created by open_db_port.py
    and detaches them from subnets.
    """
    print("Cleanup security list..")
    db_subnet_ids = json.loads(get_attribute("db_subnet_ids"))[0]
    wls_subnet = get_subnet_details(get_wls_subnet_id())
    wls_display_name = wls_subnet.display_name

    for key, db_subnet_id in db_subnet_ids.items():
        if not db_subnet_id:
            continue
        subnet = get_subnet_details(db_subnet_id)
        seclist_ids = subnet.security_list_ids
        found_seclists=[]

        seclist_suffix=(wls_display_name.split('-')[1] if '-' in wls_display_name else "")
        for seclist_id in seclist_ids:
            seclist = get_seclist_details(seclist_id)
            if seclist_suffix in seclist.display_name:
                found_seclists.append(seclist)

        for seclist in found_seclists:
            print(f"Removing security list: {seclist.display_name} from subnet: {subnet.display_name}")

            #Removing the Security List from the list of Security Lists of the subnet.
            updated_lists = [sid for sid in seclist_ids if sid != seclist.id]
            update_subnet_details(subnet.id, "security_list_ids", updated_lists)

            # Deleting the security list
            try:
                core_client.delete_security_list(seclist.id)
                print(f"    Deleted Security List: {seclist.display_name}")

            except ServiceError as e:
                print(f"    Failed to delete {seclist.display_name}: {e.message}")

            except Exception as e:
                print(f"Unexpected error while updating security list {seclist.display_name}: {str(e)}")









if __name__ == "__main__":
    try:
        cleanup_security_lists()
        print("Cleanup complete. You can now safely run 'terraform destroy'.")
    except Exception as e:
        print(f"Cleanup failed: {str(e)}")
        sys.exit(1)