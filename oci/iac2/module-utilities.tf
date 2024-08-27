# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl


module "utilities" {
  count  = local.create_domain_enabled && var.bastion_public_ip != null ? 1 : 0 #&& var.create_bastion
  source = "./modules/utilities"
  region = var.region

  # WLS Servers in Domain
  await_node_readiness = var.await_node_readiness
  expected_node_count  = local.num_oci_instances


  # Bastion/operator connection
  ssh_private_key = sensitive(local.ssh_private_key)
  bastion_host    = local.bastion_public_ip
  bastion_user    = var.bastion_user
#  operator_host   = local.operator_private_ip
#  operator_user   = var.operator_user

#  bucket_name          = ""
  resource_name_prefix = local.wls_domain_name
  wlsserver_pools      = one(module.wlsservers[*].wlsserver_instance_changes)
  restore_wls_archives     = var.restore_wls_archives
  user = local.os_user
  user_id = local.os_uid
  group = local.os_groups
  group_id = local.os_gid
  text_to_replace_in_config = local.wls_config_text_changes
  wls_domain_path = local.domain_path
}
