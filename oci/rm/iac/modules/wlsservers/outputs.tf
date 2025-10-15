# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
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


output "wlsserver_instance_ips" {
  description = "Created wlsserver instance private IPs by instance pool"
  value = lookup(local.wlsserver_instance_ips,"instance",{})
}

output "wlsserver_private_ips" {
  value = local.wlsserver_private_ips_list
}

output "wlsserver_hostnames" {
  description = "List of all wlsserver hostnames (FQDNs)"
  value = [
    for _, instance in local.enabled_instances : instance.hostname
  ]
}