# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

# Output for DB-side Local Peering Gateways
output "dblpg_ids" {
  description = "Map of datasource keys to DB LPG IDs or null if not peered"
  value = {
    for k, v in var.datasources :
    k => v.is_vcn_peering ? try(oci_core_local_peering_gateway.dblpg[k].id, null) : null
  }
}

# Output for WLS-side Local Peering Gateways
output "wlslpg_ids" {
  description = "Map of datasource keys to WLS LPG IDs or null if not peered"
  value = {
    for k, v in var.datasources :
    k => v.is_vcn_peering ? try(oci_core_local_peering_gateway.wlslpg[k].id, null) : null
  }
}