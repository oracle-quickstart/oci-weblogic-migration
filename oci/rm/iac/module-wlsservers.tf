# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  wlsserver_count_expected = coalesce(one(module.wlsservers[*].wlsserver_count_expected), 0)

  # TODO (joi) Future version to include clusters and set of WebLogic Servers on different compartments.
  #  # Distinct list of compartments for enabled wlsserver pools
  #  wlsserver_compartments = distinct(compact([
  #    for k, v in var.wlsserver_pools : lookup(v, "compartment_id", local.compartment_id)
  #    if tobool(lookup(v, "create", true))
  #  ]))

  wlsserver_compartments = [local.compartment_id]

  create_domain_enabled            = var.create_domain #|| coalesce(var.cluster_id, "none") != "none"
  weblogic_server_instance_details = length(try(var.wlsserver_pools, {})) > 0 ? var.wlsserver_pools : local.wls_instance_params
  os_user = local.os_users

  #Images

  # Volumes
  block_volume_devices = {
    "middleware" = {
      volume_mount_point = local.oracle_home
      display_name       = "mw"
      device             = "/dev/oracleoci/oraclevdb"
      size               =  var.wlsserver_mw_volume_size
    },
    "jdk" = {
      volume_mount_point = local.jdk_home
      display_name       = "javaHome"
      device             = "/dev/oracleoci/oraclevdc"
      size               =  var.wlsserver_jdk_volume_size
    },
    "domain" = {
      volume_mount_point = local.domain_path
      display_name       = local.wls_domain_name
      device             = "/dev/oracleoci/oraclevdd"
      size               = var.wlsserver_domain_volume_size
    }
  }
}

# Default wlsservers sub-module implementation for Weblogic Domain nodes
module "wlsservers" {
  count  = local.create_domain_enabled ? 1 : 0
  source = "./modules/wlsservers"

  # Common
  compartment_id      = local.wlsserver_compartment_id
  tenancy_id          = local.tenancy_id
  state_id            = local.state_id
  ad_numbers          = local.ad_numbers
  ad_numbers_to_names = local.ad_numbers_to_names

  # Domain-wide
  wlsdomain_dns        = var.custom_dns
  wlsserver_pools      = local.weblogic_server_instance_details


  # wlsservers
  assign_dns        = var.assign_dns
  assign_public_ip  = var.wlsserver_is_public
  block_volume_type = var.wlsserver_block_volume_type
  #  capacity_reservation_id    = var.wlsserver_capacity_reservation_id
  cloud_init                 = var.wlsserver_cloud_init
  disable_default_cloud_init = var.wlsserver_disable_default_cloud_init
  image_id                   = var.wlsserver_image_id
#  image_ids                  = local.image_ids
  image_ids = {}
  image_os                   = var.wlsserver_image_os
  image_os_version           = var.wlsserver_image_os_version
  image_type                 = var.wlsserver_image_type
  node_labels                = var.wlsserver_node_labels
  node_metadata              = var.wlsserver_node_metadata
  platform_config            = var.platform_config
  pv_transit_encryption      = var.wlsserver_pv_transit_encryption
  shape                      = var.wlsserver_shape
  ssh_public_key             = local.ssh_public_key
  timezone                   = var.timezone
  volume_kms_key_id          = var.wlsserver_volume_kms_key_id
#  managedserver_nsg_ids      = concat(var.managedserver_nsg_ids, [try(module.network.wlsserver_nsg_id, null)])
  managedserver_nsg_ids       = coalescelist([module.network.wlsserver_nsg_id])
#  adminserver_nsg_ids        = concat(var.adminserver_nsg_ids, [try(module.network.adminserver_nsg_id, null)])
  adminserver_nsg_ids         = coalescelist([module.network.adminserver_nsg_id])
  wlsserver_subnet_id        = try(module.network.wlsserver_subnet_id, "") # safe destroy; validated in submodule
  wlsserver_ports            = local.wls_domain_all_discovered_ports
  adminserver_ports          = local.wls_admin_server_ports

  # Volumes
  wls_archived_volumes = local.block_volume_devices

  # backups
  bucket_name = var.bucket_name
  # Tagging
  tag_namespace    = var.tag_namespace
  defined_tags     = local.wlsservers_defined_tags
  freeform_tags    = local.wlsservers_freeform_tags
  use_defined_tags = var.use_defined_tags

  #WLS Domain Details
  wls_domain_home =  local.domain_path
  resource_name_prefix = local.wls_domain_name


  #OS WLS
  user     = local.os_user
  user_id  = local.os_uid
  group    = local.os_groups
  group_id = local.os_gid

  #Datasources
  wls_datasources_config = var.wls_configured_datasource_text

  #Changes on WebLogic config due to new OCI Environment.
  text_to_replace_in_config=local.wls_config_text_changes
  # Development Mode Prod or Development
  is_development = contains(["DEV"], var.release )
  mode = var.release
  vm_scripts_path = var.vm_script_path

  depends_on = [
    module.iam,
  ]

}

## OUTPUTS ###

output "wlsserver_instances" {
  description = "Created wlsserver pools (mode == 'instance')"
  value       = var.output_detail && local.wlsserver_count_expected > 0 ? try(one(module.wlsservers[*].wlsserver_instances), null) : null
}

output "wlsserver_pool_ips" {
  description = "Created wlsserver instance private IPs by pool for available modes ('node-pool', 'instance')."
  value       = local.wlsserver_count_expected > 0 ? try(one(module.wlsservers[*].wlsserver_pool_ips), null) : null
}

output "wls_domain_name" {
  description = "Migrated Weblogic Domain name"
  value       = local.wls_domain_name
}

output "ssh_to_nodes" {
  description = "SSH command to Weblogic Server Instances"
  value= local.wlsserver_count_expected > 0 ? [for ip,id in try(one(module.wlsservers[*].wlsserver_pool_ips), null) : join(" ", concat(["ssh"],
    local.bastion_proxy_command, [ip] ))] : null
}

