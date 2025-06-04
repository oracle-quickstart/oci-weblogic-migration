# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

resource "oci_core_local_peering_gateway" "dblpg_0" {
  #Required
  compartment_id = var.db_network_compartment_id
  display_name   = "dblpg_0"
  vcn_id         = var.db_existing_vcn_id
}

resource "oci_core_local_peering_gateway" "wlslpg_0" {
  #Required
  depends_on     = [time_sleep.wait_for_wls_vcn_dns_resolver]
  compartment_id = var.compartment_id
  display_name   = "wlslpg_0"
  vcn_id         = var.vcn_id
  peer_id        = oci_core_local_peering_gateway.dblpg_0.id
}

# Add to the DNS resolver of the WebLogic VCN the default view of the DNS resolver of the DB VCN
resource "oci_dns_resolver" "wls_oci_dsn_resolver" {
  resolver_id = data.oci_core_vcn_dns_resolver_association.wls_vcn_resolver_association.dns_resolver_id
  scope       = "PRIVATE"
  attached_views {
    view_id = data.oci_dns_resolver.db_vcn_resolver.default_view_id
  }
}