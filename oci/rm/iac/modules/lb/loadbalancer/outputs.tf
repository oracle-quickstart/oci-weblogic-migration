# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

output "wls_loadbalancer_id" {
  value       = oci_load_balancer_load_balancer.wls_loadbalancer.id
  description = "The OCID of the load balancer"
}

output "wls_loadbalancer_ip_addresses" {
  value       = oci_load_balancer_load_balancer.wls_loadbalancer.ip_address_details
  description = "The list of IP addresses of the load balancer"
}
