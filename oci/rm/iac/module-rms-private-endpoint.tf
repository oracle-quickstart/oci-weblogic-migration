# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

locals{
#  is_bastion_instance_required = (var.is_bastion_instance_required && var.subnet_type != "Use Public Subnet") || var.wls_existing_vcn_id == "" || (var.wls_existing_vcn_id != "" && var.wls_subnet_id == "") ? true : false

  # Resource Manager Endpoint
  is_rms_private_endpoint_required  = var.is_rms_private_endpoint_required && var.vcn_id != "" && var.subnets.wlsservers.id != "" ? true : false
  add_new_rms_private_endpoint      = local.is_rms_private_endpoint_required && var.add_rms_private_endpoint == "Create New Resource Manager Endpoint" ? true : false
  add_existing_rms_private_endpoint = local.is_rms_private_endpoint_required && var.add_rms_private_endpoint == "Use Existing Resource Manager Endpoint" ? true : false
}


module "rms-private-endpoint" {
  source = "./modules/rms-private-endpoint"
  count  = local.is_rms_private_endpoint_required && local.add_new_rms_private_endpoint ? 1 : 0

  vcn_id                     = local.vcn_id
  compartment_id             = coalesce(var.network_compartment_id, local.compartment_id)
  private_endpoint_subnet_id = var.subnets.wlsservers.id != "" ? var.subnets.wlsservers.id : module.network.wlsserver_subnet_id
  private_endpoint_nsg_id    = var.subnets.wlsservers.id != "" ? (var.add_existing_nsg ? [var.nsgs.adminserver.id] : []) : module.network.adminserver_nsg_id
  resource_name_prefix       = var.state_id

  tags = {
    defined_tags  = local.resource_manager_defined_tags
    freeform_tags = local.resource_manager_freeform_tags
  }
}