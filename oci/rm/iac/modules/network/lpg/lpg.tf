# Copyright (c) 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

resource "time_sleep" "wait_for_wls_vcn_dns_resolver" {
  create_duration = "20s"
}

resource "oci_core_local_peering_gateway" "dblpg_0" {
  #Required
  compartment_id = var.db_network_compartment_id
  display_name   = "dblpg_0"
  vcn_id = var.db_existing_vcn_id

  defined_tags     = var.defined_tags
  freeform_tags    = var.freeform_tags

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}

resource "oci_core_local_peering_gateway" "wlslpg_0" {
  #Required
  depends_on = [time_sleep.wait_for_wls_vcn_dns_resolver]
  compartment_id = var.compartment_id
  display_name   = "wlslpg_0"
  vcn_id = var.vcn_id
  peer_id = oci_core_local_peering_gateway.dblpg_0.id

  defined_tags     = var.defined_tags
  freeform_tags    = var.freeform_tags

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}

# Add to the DNS resolver of the WebLogic VCN the default view of the DNS resolver of the DB VCN
resource "oci_dns_resolver" "wls_oci_dsn_resolver" {
  count      = var.wls_existing_vcn_id != "" ? 1 : 0
  resolver_id = data.oci_core_vcn_dns_resolver_association.wls_vcn_resolver_association[0].dns_resolver_id
  scope       = "PRIVATE"
  attached_views {
    view_id = data.oci_dns_resolver.db_vcn_resolver[0].default_view_id
  }
  # Prevent Terraform from resetting fields fields like attached_views and rules on reapply,
  # removing changes done manually (e.g add another view)
  lifecycle {
    ignore_changes = all
  }
}