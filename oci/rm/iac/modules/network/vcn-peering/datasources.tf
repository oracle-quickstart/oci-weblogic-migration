# Copyright (c) 2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {
  db_resolver_views = {
    for k, resolver in data.oci_dns_resolver.db_vcn_resolver :
    k => resolver.default_view_id
  }
}

resource "time_sleep" "wait_for_wls_vcn_dns_resolver" {
  create_duration = "20s"
}

# When a new VCN is created, the DNS resolver is created asynchronously. Therefore, this data source might return null
# if called right after the VCN is created. That is why we are adding a dependency on the timer. We will wait a certain amount
# of seconds if new WebLogic VCN is used

data "oci_core_vcn_dns_resolver_association" "wls_vcn_resolver_association" {
  depends_on = [time_sleep.wait_for_wls_vcn_dns_resolver]
  vcn_id     = var.vcn_id
}

data "oci_core_vcn_dns_resolver_association" "db_vcn_resolver_association" {
  for_each = { for k, v in var.datasources : k => v if v.is_vcn_peering }

  vcn_id = each.value.db_existing_vcn_id
}

data "oci_dns_resolver" "db_vcn_resolver" {
  for_each = data.oci_core_vcn_dns_resolver_association.db_vcn_resolver_association

  resolver_id = each.value.dns_resolver_id
  scope       = "PRIVATE"
}