# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "oci_core_local_peering_gateway" "dblpg" {
  for_each = { for k, v in var.datasources : k => v if v.is_vcn_peering }
  #Required
  compartment_id = each.value.db_network_compartment_id
  display_name   = format("db-%v-%v", var.lpg_name, each.key)
  vcn_id         = each.value.db_existing_vcn_id
}

resource "oci_core_local_peering_gateway" "wlslpg" {
  for_each = { for k, v in var.datasources : k => v if v.is_vcn_peering }
  #Required
  compartment_id = var.compartment_id
  display_name   = format("wls-%v-%v", var.lpg_name, each.key)
  vcn_id         = var.vcn_id
}

# Add to the DNS resolver of the WebLogic VCN the default view of the DNS resolver of the DB VCN
resource "oci_dns_resolver" "wls_oci_dns_resolver" {
  resolver_id = data.oci_core_vcn_dns_resolver_association.wls_vcn_resolver_association.dns_resolver_id
  scope       = "PRIVATE"

  dynamic "attached_views" {
    for_each = local.db_resolver_views
    content {
      view_id = attached_views.value
    }
  }
}