locals {
  network_compartment_id       = var.network_compartment_id == "" ? var.compartment_ocid : var.network_compartment_id
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

  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}