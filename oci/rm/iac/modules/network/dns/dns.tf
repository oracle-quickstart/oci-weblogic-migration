# Copyright (c) 2025, Oracle Corporation and/or affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

##################################################
# Locals - Auto map hostnames to private IPs
##################################################

locals {
  # Reverse zones - one per /24 subnet in host IP map
  reverse_zones = {
    for ip in values(var.forward_dns_records) :
    join(".", slice(split(".", ip), 0, 3)) => "${join(".", reverse(slice(split(".", ip), 0, 3)))}.in-addr.arpa"
  }

  # Map each PTR record to its appropriate reverse zone prefix
  ptr_record_zone_prefix = {
    for fqdn, ip in var.reverse_ptr_records :
    fqdn => join(".", slice(split(".", ip), 0, 3))
  }
}

##################################################
# Private DNS View
##################################################
resource "oci_dns_view" "private_view" {
  compartment_id = var.compartment_id
  scope          = "PRIVATE"
}

##################################################
# Forward DNS Zone
##################################################
resource "oci_dns_zone" "private_zone" {
  name            = "mycompany.internal"
  zone_type       = "PRIMARY"
  compartment_id  = var.compartment_id
  scope           = "PRIVATE"
  view_id         = oci_dns_view.private_view.id
}

##################################################
# Reverse DNS Zones
##################################################
resource "oci_dns_zone" "reverse_zone" {
  for_each        = local.reverse_zones
  name            = each.value
  zone_type       = "PRIMARY"
  compartment_id  = var.compartment_id
  scope           = "PRIVATE"
  view_id         = oci_dns_view.private_view.id
}

##################################################
# Link View to VCN Resolver
##################################################
data "oci_core_vcn_dns_resolver_association" "wls_vcn_resolver_association" {
  vcn_id = var.wlsserver_vcn_id
}

resource "oci_dns_resolver" "wls_oci_dns_resolver" {
  resolver_id = data.oci_core_vcn_dns_resolver_association.wls_vcn_resolver_association.dns_resolver_id
  scope       = "PRIVATE"

  attached_views {
    view_id = oci_dns_view.private_view.id
  }
}

##################################################
# Forward A Records
##################################################
resource "oci_dns_rrset" "forward_records" {
  for_each = var.forward_dns_records

  zone_name_or_id = oci_dns_zone.private_zone.id
  domain          = each.key
  rtype           = "A"
  compartment_id  = var.compartment_id

  items {
    domain = each.key
    rdata  = each.value
    rtype  = "A"
    ttl    = 60
  }

  lifecycle {
    ignore_changes = [items]
  }
}

##################################################
# Reverse PTR Records
##################################################
resource "oci_dns_rrset" "reverse_ptr_records" {
  for_each = var.reverse_ptr_records

  # Get reverse zone prefix dynamically for each IP
  zone_name_or_id = oci_dns_zone.reverse_zone[local.ptr_record_zone_prefix[each.key]].id

  domain = "${element(split(".", each.value), 3)}.${oci_dns_zone.reverse_zone[local.ptr_record_zone_prefix[each.key]].name}"
  rtype  = "PTR"
  compartment_id = var.compartment_id

  items {
    domain = "${element(split(".", each.value), 3)}.${oci_dns_zone.reverse_zone[local.ptr_record_zone_prefix[each.key]].name}"
    rdata  = each.key
    rtype  = "PTR"
    ttl    = 60
  }

  lifecycle {
    ignore_changes = [items]
  }
}
