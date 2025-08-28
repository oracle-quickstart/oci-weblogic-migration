# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  # Extract first ListenAddress from Server section
  first_listen_address = values(var.wls_data.topology.Server)[0].ListenAddress

  # Get domain name (everything after the first dot)
  source_domain_name = join(".", slice(split(".", local.first_listen_address), 1, length(split(".", local.first_listen_address))))
}

data "oci_core_vcn" "secondary_vcn" {
  #Required
  vcn_id = var.wlsserver_vcn_id
}

data "oci_core_vcn_dns_resolver_association" "secondary_dns_resolver_association" {
  #Required
  vcn_id = var.wlsserver_vcn_id
}

data "oci_dns_resolver" "secondary_dns_resolver" {
  #Required
  resolver_id = data.oci_core_vcn_dns_resolver_association.secondary_dns_resolver_association.dns_resolver_id
  scope = "PRIVATE"
}

# Create the private view and zone in Secondary(OCI)
########################################################################################################
resource "oci_dns_view" "private_view_in_secondary" {
  #Required
  compartment_id = var.compartment_id
  scope = "PRIVATE"

  #Optional
  display_name = local.source_domain_name
}

resource "oci_dns_zone" "zone_in_secondary" {
  #Required
  compartment_id = var.compartment_id
  name = local.source_domain_name
  zone_type = "PRIMARY"

  #Optional
  scope = "PRIVATE"
  # This zone must be added to the private view
  view_id = oci_dns_view.private_view_in_secondary.id
}

# Add the entries to zone_in_secondary (source names with secondary IPs)
########################################################################################################
resource "oci_dns_rrset" "new_rrset_in_secondary" {
  count =  var.wlsserver_count_expected

  #Required
  domain = "${var.primary_nodes_fqdns[count.index]}.${oci_dns_zone.zone_in_secondary.name}"
  rtype = "A"
  zone_name_or_id = oci_dns_zone.zone_in_secondary.id

  #Optional
  compartment_id = var.compartment_id
  items {
    #Required
    domain = "${var.primary_nodes_fqdns[count.index]}.${oci_dns_zone.zone_in_secondary.name}"
    rdata = var.secondary_nodes_IPs[count.index]
    rtype = "A"
    ttl = "120"
  }
  scope = "PRIVATE"
  view_id = oci_dns_view.private_view_in_secondary.id
}


# Add the secondary private view to secondary VCN resolver
########################################################################################################

# CAUTION!!!! NOT PROVIDING THE LIST OF THE EXISTING VIEWS REPLACES THE ATTACHED VIEWS WITH THE NEW ONE ONLY (does not add it)
resource "oci_dns_resolver" "secondary_resolver" {

  #Required
  resolver_id = data.oci_dns_resolver.secondary_dns_resolver.id
  scope = "PRIVATE"

  #With this we list the existing views, if not, they get removed
  dynamic attached_views {
    for_each = data.oci_dns_resolver.secondary_dns_resolver.attached_views[*].view_id
    content {
      view_id = attached_views.value
    }
  }
  #Then add the new one
  attached_views {
    view_id= oci_dns_view.private_view_in_secondary.id
  }
}