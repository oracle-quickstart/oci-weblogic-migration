# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

output "wlsserver_instances" {
  description = "Created wlsserver pools (mode == 'instance')"
  value       = local.wlsserver_instances
}

#output "wlsserver_pool_ids" {
#  description = "Created wlsserver pool IDs"
#  value       = local.wlsserver_pool_ids
#}

output "wlsserver_pool_ips" {
  description = "Created wlsserver instance private IPs by pool for available modes ('node-pool', 'instance')."
  value       = local.wlsserver_pool_ips
}

output "wlsserver_count_expected" {
  description = "# of nodes expected from created wlsserver pools"
  value       = local.expected_node_count
}


#output "wlsserver_drain_expected" {
#  description = "# of nodes expected to be draining in wlsserver pools"
#  value       = local.expected_drain_count
#}

