# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl


module "utilities" {
  count  = local.create_domain_enabled && local.operator_enabled ? 1 : 0
  source = "./modules/utilities"
  region = var.region

  # WLS Servers in Domain
  await_node_readiness = var.await_node_readiness
  expected_node_count  = local.num_oci_instances


  # Bastion/operator connection
  ssh_private_key = sensitive(local.ssh_private_key)
  bastion_host    = local.bastion_public_ip
  bastion_user    = var.bastion_user
  operator_host   = local.operator_private_ip
  operator_user   = var.operator_user

}
