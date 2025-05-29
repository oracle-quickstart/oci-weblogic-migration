# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_core_vcn_dns_resolver_association" "wls_vcn_resolver_association" {
  count      = var.wls_existing_vcn_id != "" ? 1 : 0
  vcn_id     = var.wls_existing_vcn_id
}

data "oci_core_vcn_dns_resolver_association" "db_vcn_resolver_association" {
  count      = var.wls_existing_vcn_id != "" ? 1 : 0
  vcn_id = var.db_existing_vcn_id
}

data "oci_dns_resolver" "db_vcn_resolver" {
  count      = var.wls_existing_vcn_id != "" ? 1 : 0
  resolver_id = data.oci_core_vcn_dns_resolver_association.db_vcn_resolver_association[0].dns_resolver_id
  scope       = "PRIVATE"
}