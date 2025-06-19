# Copyright (c) 2024,2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Identity
output "dynamic_group_ids" { value = module.wls.dynamic_group_ids }
output "policy_statements" { value = module.wls.policy_statements }

# Domain Details
output "wls_domain_name" { value = module.wls.wls_domain_name }
output "weblogic_instances" { value = module.wls.wlsserver_pool_ips }

# Network Details
output "virtual_cloud_network_id" {
  value = try(module.wls.vcn_id, "")
}

output "bastion_instance_id" {
  value = try(module.wls.bastion_id, "")
}

output "bastion_public_ip" {
  value = try(module.wls.bastion_public_ip, "")
}

output "load_balancer_id" {
  value = try(module.wls.wls_loadbalancer_id, "")
}

output "load_balancer_ip" {
  value = try(element(flatten(module.wls.wls_loadbalancer_ip), 0).ip_address, "")
}

# value to be added later when vcn peering support is added, and the variable is defined
output "is_vcn_peered" {
  value = local.is_vcn_peering
}

# Terraform State Id
output "resource_identifier_value" {
  value = module.wls.state_id
}

# In case the bastion ip is null, <bastion_ip> will be displayed in the string
output "ssh_command" {
  value = format("ssh -i <privateKey> -o ProxyCommand=\"ssh -i <privateKey> -W %s -p 22 opc@%s\" -p 22 %s", "%h:%p", coalesce(module.wls.bastion_public_ip, "<bastion_ip>"), "opc@<wls_vm_private_ip>")
}

output "ssh_command_with_dynamic_port_forwarding" {
  value = "ssh -i <privatekey> -C -D <local-port> opc@ <bastion_ip>"
}

# WebLogic Details
output "weblogic_version" {
  value = local.wls_version
}

output "weblogic_console" {
  value = local.admin_console_url
}