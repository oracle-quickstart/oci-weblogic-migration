# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  dns_label = replace(var.dns_label, "-", "")
}

resource "oci_core_subnet" "wls-subnet" {
  cidr_block                 = var.cidr_block
  display_name               = var.subnet_name
  dns_label                  = local.dns_label
  compartment_id             = var.compartment_id
  vcn_id                     = var.vcn_id
  route_table_id             = var.route_table_id
  prohibit_public_ip_on_vnic = var.prohibit_public_ip

  defined_tags     = var.defined_tags
  freeform_tags    = var.freeform_tags

  lifecycle {
    ignore_changes = [
      freeform_tags, defined_tags, display_name,
      cidr_block, dns_label, security_list_ids, vcn_id, route_table_id,
    ]
  }
}