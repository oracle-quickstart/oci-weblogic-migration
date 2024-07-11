import json
import terrascript

def convert_json_to_terraform(filename):
    with open(filename, 'r') as file:
        data = json.load(file)

    terraform_config = terrascript.Terrascript()

    for item in data:
        resource = terrascript.Resource(
            "oci_compute_instance",
            item["name"],
            args={
                "availability_domain": item.get("availability_domain"),
                "capacity_reservation_id": item.get("capacity_reservation_id"),
                "compartment_id": item.get("compartment_id"),
                "dedicated_vm_host_id": item.get("dedicated_vm_host_id"),
                "defined_tags": item.get("defined_tags"),
                "display_name": item.get("display_name"),
                "extended_metadata": item.get("extended_metadata"),
                "freeform_tags": item.get("freeform_tags"),
                "image": item.get("image"),
                "ipxe_script": item.get("ipxe_script"),
                "launch_options": item.get("launch_options"),
                "metadata": item.get("metadata"),
                "shape": item.get("shape"),
                "source_details": item.get("source_details"),
                "subnet_id": item.get("subnet_id"),
                "tenancy": item.get("tenancy"),
                "timeouts": item.get("timeouts"),
                "vcn_id": item.get("vcn_id"),
            },
        )

        terraform_config += resource

    with open("output.tf", "w") as file:
        terraform_config.write(file)

class TerraformHelper(object):
    def __init__(self, model_context, deployments_dictionary, base_location, discovered_model
                 , wlst_mode=WlstModes.OFFLINE, aliases=None, credential_injector=None, extra_tokens=None):
        pass
