# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Terraform
output "state_id" { value = module.wls-migration.state_id }

# Network
output "vcn_id" { value = module.wls-migration.vcn_id }
#output "drg_id" { value = module.wls-migration.drg_id }
output "ig_route_table_id" { value = module.wls-migration.ig_route_table_id }
output "nat_route_table_id" { value = module.wls-migration.nat_route_table_id }

# Bastion
output "bastion_id" { value = module.wls-migration.bastion_id }
output "bastion_public_ip" { value = module.wls-migration.bastion_public_ip }
output "bastion_subnet_id" { value = module.wls-migration.bastion_subnet_id }
output "bastion_subnet_cidr" { value = module.wls-migration.bastion_subnet_cidr }
output "bastion_nsg_id" { value = module.wls-migration.bastion_nsg_id }
output "bastion_ssh_command" { value = module.wls-migration.ssh_to_bastion }
output "bastion_ssh_secret_id" { value = var.ssh_kms_secret_id }

# Loadbalancer
output "int_lb_subnet_id" { value = module.wls-migration.int_lb_subnet_id }
output "pub_lb_subnet_id" { value = module.wls-migration.pub_lb_subnet_id }
output "int_lb_nsg_id" { value = module.wls-migration.int_lb_nsg_id }
output "int_lb_subnet_cidr" { value = module.wls-migration.int_lb_subnet_cidr }
output "pub_lb_nsg_id" { value = module.wls-migration.pub_lb_nsg_id }
output "pub_lb_subnet_cidr" { value = module.wls-migration.pub_lb_subnet_cidr }

# wlsservers
output "wlsserver_subnet_id" { value = module.wls-migration.wlsserver_subnet_id }
output "wlsserver_subnet_cidr" { value = module.wls-migration.wlsserver_subnet_cidr }
output "wlsserver_nsg_id" { value = module.wls-migration.wlsserver_nsg_id }
