locals {
  network_compartment_id       = var.network_compartment_id == "" ? var.compartment_ocid : var.network_compartment_id
  wlsservers_freeform_tags     = merge(lookup(var.freeform_tags, "wlsservers", {}), var.wlsservers_freeform_tags)
  wlsservers_defined_tags      = merge(lookup(var.defined_tags, "wlsservers", {}), var.wlsservers_defined_tags)
}

  /* Create back end  private subnet for wls */
module "network-wls-private-subnet" {
  source          = "./modules/network/subnet"
  compartment_id  = local.network_compartment_id
  vcn_id          = local.vcn_id
  #dhcp_options_id = module.network-vcn-config[0].dhcp_options_id
  #This is to prevent Terraform from resetting the route table on reapply. Peering module will set a new route table
  route_table_id     = var.nat_route_table_id
  subnet_name        = format("wlsservers-%v", var.state_id)
  dns_label          = format("wlsservers-%v", substr(strrev(var.state_id), 0, 7))
  cidr_block         = var.wlsserver_subnet_cidr
  prohibit_public_ip = true

  # Standard tags as defined if enabled for use, or freeform
  # User-provided tags are merged last and take precedence
  use_defined_tags = var.use_defined_tags
  tag_namespace    = var.tag_namespace
  defined_tags = merge(var.use_defined_tags ? {
    "${var.tag_namespace}.state_id" = local.state_id,
    "${var.tag_namespace}.role"     = "wlsservers",
  } : {}, local.wlsservers_defined_tags)
  freeform_tags = merge(var.use_defined_tags ? {} : {
    "state_id" = local.state_id,
    "role"     = "wlsservers",
  }, local.wlsservers_freeform_tags)
}