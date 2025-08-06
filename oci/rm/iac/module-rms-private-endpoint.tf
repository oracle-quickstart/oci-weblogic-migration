# Copyright (c) 2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

module "rms-private-endpoint" {
  source = "./modules/rms-private-endpoint"
  count  = var.create_bastion ? 0 : 1

  vcn_id                     = local.vcn_id
  compartment_id             = coalesce(var.network_compartment_id, local.compartment_id)
  private_endpoint_subnet_id = module.network-wls-private-subnet.subnet_id
  private_endpoint_nsg_id    = [module.network.adminserver_nsg_id]
  resource_name_prefix       = local.state_id

  tags = {
    defined_tags  = local.resource_manager_defined_tags
    freeform_tags = local.resource_manager_freeform_tags
  }
}