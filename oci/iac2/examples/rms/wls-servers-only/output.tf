# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Terraform
output "state_id" { value = module.wls.state_id }

# Network
output "wlsserver_subnet_id" { value = var.wlsserver_subnet_id }
output "managedserver_nsg_id" { value = var.managedserver_nsg_id }
output "adminserver_nsg_id" { value = var.adminserver_nsg_id }

# Identity
output "dynamic_group_ids" { value = module.wls.dynamic_group_ids }
output "policy_statements" { value = module.wls.policy_statements }
#output "create_iam_wlsserver_policy" { value = var.create_iam_wlsserver_policy }

# Domain Details
output "wls_domain_name" { value = module.wls.wls_domain_name }
output "wlsserver_pool_mode" { value = var.wlsserver_pool_mode }
output "wlsserver_shape" { value = var.wlsserver_shape }
output "wlsserver_pool_size" { value = var.wlsserver_pool_size }
output "wlsserver_image_id" { value = local.wlsserver_image_id }
output "weblogic_instances_private_ips" { value = module.wls.wlsserver_pool_ips }

output "wlsserver_pool_ids" {
  value = concat(
    values(coalesce(module.wls.wlsserver_instances, {})),
  )
}

