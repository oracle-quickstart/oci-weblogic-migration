
module "network-lb-nsg" {
  source         = "./modules/network/nsg"
  count          = local.use_existing_lb ? 0 : local.add_load_balancer && !local.use_existing_subnets && local.lb_subnet_1_subnet_cidr != "" ? 1 : 0
  compartment_id = local.network_compartment_id
  vcn_id         = local.vcn_id
  nsg_name       = "${local.service_name_prefix}-lb-nsg"

  tags = {
    defined_tags  = local.defined_tags
    freeform_tags = local.free_form_tags
  }
  tag_namespace    = ""
  use_defined_tags = false
}

#module "network-bastion-nsg" {
#  source         = "./modules/network/nsg"
#  count          = local.is_bastion_instance_required && var.existing_bastion_instance_id == "" && !local.use_existing_subnets && local.bastion_subnet_cidr != "" ? 1 : 0
#  compartment_id = local.network_compartment_id
#  vcn_id         = local.vcn_id
#  nsg_name       = "${local.service_name_prefix}-bastion-nsg"
#
#  tags = {
#    defined_tags  = local.defined_tags
#    freeform_tags = local.free_form_tags
#  }
#  tag_namespace    = ""
#  use_defined_tags = false
#}
 #TODO: JOI - FSS not included in V1.
#module "network-mount-target-nsg" {
#  source         = "./modules/network/nsg"
#  count          = var.add_fss && !local.use_existing_subnets && local.mount_target_subnet_cidr != "" ? 1 : 0
#  compartment_id = local.network_compartment_id
#  vcn_id         = local.vcn_id
#  nsg_name       = "${local.service_name_prefix}-mount-target-nsg"
#
#  tags = {
#    defined_tags  = local.defined_tags
#    freeform_tags = local.free_form_tags
#  }
#  tag_namespace    = ""
#  use_defined_tags = false
#}

module "network-compute-admin-nsg" {
  source         = "./modules/network/nsg"
  #  count          = !local.use_existing_subnets && local.wls_subnet_cidr != "" ? 1 : 0
#  count = 1
  compartment_id = local.network_compartment_id
  vcn_id         = local.vcn_id
  nsg_name       = format("%s-%s",local.wls_domain_name,"admin-server-nsg")

  tags = {
    defined_tags  = local.defined_tags
    freeform_tags = local.free_form_tags
  }
  tag_namespace    = ""
  use_defined_tags = false
}

module "network-compute-managed-nsg" {
  source         = "./modules/network/nsg"
  #  count          = !local.use_existing_subnets && local.wls_subnet_cidr != "" ? 1 : 0
#  count = 1
  compartment_id = local.network_compartment_id
  vcn_id         = local.vcn_id
  nsg_name       = format("%s-%s",local.wls_domain_name,"managed-server-nsg")

  tags = {
    defined_tags  = local.defined_tags
    freeform_tags = local.free_form_tags
  }
  tag_namespace    = ""
  use_defined_tags = false
}


#//////////////////////////////#///////////////#///////////////##
#  Todo: JOI - Usefull code for NSGs.
#//////////////////////////////#///////////////#///////////////##
#locals {
#  # setproduct works with sets and lists, but the variables are both maps
#  # so convert them first.
#  networks = [
#  for key, network in var.networks : {
#    key        = key
#    cidr_block = network.cidr_block
#  }
#  ]
#  subnets = [
#  for key, subnet in var.subnets : {
#    key    = key
#    number = subnet.number
#  }
#  ]
#
#  network_subnets = [
#  # in pair, element zero is a network and element one is a subnet,
#  # in all unique combinations.
#  for pair in setproduct(local.networks, local.subnets) : {
#    network_key = pair[0].key
#    subnet_key  = pair[1].key
#    network_id  = aws_vpc.example[pair[0].key].id
#
#    # The cidr_block is derived from the corresponding network. Refer to the
#    # cidrsubnet function for more information on how this calculation works.
#    cidr_block = cidrsubnet(pair[0].cidr_block, 4, pair[1].number)
#  }
#  ]
#}