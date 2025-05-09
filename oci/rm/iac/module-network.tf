# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

# Copyright (c) 2017, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

data "oci_core_vcn" "oke" {
  count  = var.create_vcn ? 0 : 1
  vcn_id = coalesce(var.vcn_id, "none")
}

locals {
  # Created VCN if enabled, else var.vcn_id
  vcn_id = var.create_vcn ? try(one(module.vcn[*].vcn_id), var.vcn_id) : var.vcn_id

  # Configured VCN CIDRs if creating, else from provided vcn_id
  vcn_lookup             = coalesce(one(data.oci_core_vcn.oke[*].cidr_blocks), [])
  vcn_lookup_cidr_blocks = flatten(local.vcn_lookup)
  vcn_cidrs              = var.create_vcn ? var.vcn_cidrs : local.vcn_lookup_cidr_blocks

  # Created route table if enabled, else var.ig_route_table_id
  ig_route_table_id = var.create_vcn ? try(one(module.vcn[*].ig_route_id), var.ig_route_table_id) : var.ig_route_table_id

  # Created route table if enabled, else var.nat_route_table_id
  nat_route_table_id = var.create_vcn ? try(one(module.vcn[*].nat_route_id), var.ig_route_table_id) : var.nat_route_table_id

  network_compartment_id       = var.network_compartment_id == "" ? var.compartment_ocid : var.network_compartment_id
  # Map of configured subnets to specified/generated dns_label when enabled
  # If `assign_dns = true`, use dns_label for subnet if specified or first 2 characters of subnet key
  subnet_dns_labels = { for k, v in var.subnets :
    k => coalesce(lookup(v, "dns_label", null), substr(k, 0, 2))
    if var.assign_dns
  }
}

module "vcn" {
  count          = var.create_vcn ? 1 : 0
  source         = "./modules/network/vcn"
  compartment_id = coalesce(var.network_compartment_id, local.compartment_id)

  # Standard tags as defined if enabled for use, or freeform
  # User-provided tags are merged last and take precedence
  defined_tags = merge(var.use_defined_tags ? {
    "${var.tag_namespace}.state_id" = local.state_id,
    "${var.tag_namespace}.role"     = "network",
  } : {},
    local.network_defined_tags,
  )
  freeform_tags = merge(var.use_defined_tags ? {} : {
    "state_id" = local.state_id,
    "role"     = "network",
  },
    local.network_freeform_tags,
  )

  create_internet_gateway = alltrue([
    var.vcn_create_internet_gateway != "never",    # always disable
    anytrue([                                      # enable for configurations that generally utilize it
      var.vcn_create_internet_gateway == "always", # always enable
      var.create_bastion && var.bastion_is_public, # enable for public bastion
      var.load_balancers != "internal",            # enable for cluster w/ public load balancers
    ])
  ])

  create_nat_gateway = alltrue([
    var.vcn_create_nat_gateway != "never",                # always disable
    anytrue([                                             # enable for configurations that generally utilize it
      var.vcn_create_nat_gateway == "always",             # always enable
      !var.wlsserver_is_public,                              # enable for private wlsservers
      #var.create_operator,                                # enable for operator
      contains(["internal", "both"], var.load_balancers), # enable for cluster w/ private load balancers
    ])
  ])

  create_service_gateway       = var.vcn_create_service_gateway != "never"
  internet_gateway_route_rules = var.internet_gateway_route_rules
  local_peering_gateways       = var.local_peering_gateways
  lockdown_default_seclist     = var.lockdown_default_seclist
  nat_gateway_public_ip_id     = var.nat_gateway_public_ip_id
  nat_gateway_route_rules      = var.nat_gateway_route_rules
  vcn_cidrs                    = local.vcn_cidrs
  vcn_dns_label                = var.assign_dns ? coalesce(var.vcn_dns_label, local.state_id) : null
  vcn_name                     = coalesce(var.vcn_name, "wls-${local.state_id}")
}

/* Create back end  private subnet for wls */
module "subnet" {
  source          = "./modules/network/subnet"
  compartment_id  = local.network_compartment_id
  vcn_id          = local.vcn_id
  #dhcp_options_id = module.network-vcn-config[0].dhcp_options_id
  #This is to prevent Terraform from resetting the route table on reapply. Peering module will set a new route table
  route_table_id     = var.nat_route_table_id
  subnet_name        = format("wlsservers-%v", var.state_id)
  dns_label          = lookup(local.subnet_dns_labels, "wlsservers", null)
  cidr_block         = var.wlsserver_subnet_cidr
  prohibit_public_ip = true

  # Standard tags as defined if enabled for use, or freeform
  # User-provided tags are merged last and take precedence
  defined_tags = merge(var.use_defined_tags ? {
    "${var.tag_namespace}.state_id" = local.state_id,
    "${var.tag_namespace}.role"     = "wlsservers",
  } : {}, local.wlsservers_defined_tags)
  freeform_tags = merge(var.use_defined_tags ? {} : {
    "state_id" = local.state_id,
    "role"     = "wlsservers",
  }, local.wlsservers_freeform_tags)
}

module "network" {
  source           = "./modules/network"
  state_id         = local.state_id
  compartment_id   = coalesce(var.network_compartment_id, local.compartment_id)
  defined_tags     = local.network_defined_tags
  freeform_tags    = local.network_freeform_tags
  tag_namespace    = var.tag_namespace
  use_defined_tags = var.use_defined_tags

  #allow_node_port_access       = var.allow_node_port_access
  allow_rules_internal_lb      = var.allow_rules_internal_lb
  allow_rules_public_lb        = var.allow_rules_public_lb
  allow_rules_wlsservers          = var.allow_rules_wlsservers
  allow_rules_adminserver = var.allow_rules_adminserver
  allow_adminserver_internet_access = var.allow_adminserver_internet_access
  allow_adminserver_ssh_access      = var.allow_adminserver_ssh_access
  allow_wlsserver_internet_access = var.allow_wlsservers_internet_access
  allow_wlsserver_ssh_access      = var.allow_wlsservers_ssh_access
  allow_bastion_domain_access = var.allow_bastion_domain_access
  allow_bastion_adminserver_access = var.allow_bastion_adminserver_access
  assign_dns                   = var.assign_dns
  bastion_allowed_cidrs        = var.bastion_allowed_cidrs
  bastion_is_public            = var.bastion_is_public
  create_bastion               = var.create_bastion
  nsgs                         = var.nsgs
  #  create_operator              = false            #future use
  enable_waf                   = false            #future use
  ig_route_table_id            = local.ig_route_table_id
  load_balancers               = var.load_balancers
  nat_route_table_id           = local.nat_route_table_id
  subnets                      = var.subnets
  vcn_cidrs                    = local.vcn_cidrs
  vcn_id                       = local.vcn_id
  wlsserver_is_public             = var.wlsserver_is_public
  wlsserver_ports = local.wls_domain_all_discovered_ports
  adminserver_ports = local.wls_admin_server_ports
  resource_name_prefix = local.wls_domain_name
}

# VCN
output "vcn_id" {
  description = "VCN ID"
  value       = try(local.vcn_id, null)
}
output "ig_route_table_id" {
  description = "Internet gateway route table ID"
  value       = try(local.ig_route_table_id, null)
}
output "nat_route_table_id" {
  description = "NAT gateway route table ID"
  value       = try(local.nat_route_table_id, null)
}

# Subnets
output "bastion_subnet_id" {
  value = try(module.network.bastion_subnet_id, null)
}
output "bastion_subnet_cidr" {
  value = try(module.network.bastion_subnet_cidr, null)
}
#output "operator_subnet_id" {
#  value = try(module.network.operator_subnet_id, null)
#}
#output "operator_subnet_cidr" {
#  value = try(module.network.operator_subnet_cidr, null)
#}
output "wlsserver_subnet_id" {
  #value = try(module.network.wlsserver_subnet_id, null)
  value = try(module.subnet.subnet_id)
}
output "wlsserver_subnet_cidr" {
  value = try(module.network.wlsserver_subnet_cidr, null)
}
output "int_lb_subnet_id" {
  value = try(module.network.int_lb_subnet_id, null)
}
output "int_lb_subnet_cidr" {
  value = try(module.network.int_lb_subnet_cidr, null)
}
output "pub_lb_subnet_id" {
  value = try(module.network.pub_lb_subnet_id, null)
}
output "pub_lb_subnet_cidr" {
  value = try(module.network.pub_lb_subnet_cidr, null)
}
output "fss_subnet_id" {
  value = try(module.network.fss_subnet_id, null)
}
output "fss_subnet_cidr" {
  value = try(module.network.fss_subnet_cidr, null)
}

# NSGs
output "bastion_nsg_id" {
  description = "Network Security Group for bastion host(s)."
  value       = try(module.network.bastion_nsg_id, null)
}
#output "operator_nsg_id" {
#  description = "Network Security Group for operator host(s)."
#  value       = try(module.network.operator_nsg_id, null)
#}

output "int_lb_nsg_id" {
  description = "Network Security Group for internal load balancers."
  value       = try(module.network.int_lb_nsg_id, null)
}
output "pub_lb_nsg_id" {
  description = "Network Security Group for public load balancers."
  value       = try(module.network.pub_lb_nsg_id, null)
}
output "wlsserver_nsg_id" {
  description = "Network Security Group for wlsserver nodes."
  value       = try(module.network.wlsserver_nsg_id, null)
}

output "adminserver_nsg_id" {
  description = "Network Security Group for wlsserver nodes."
  value       = try(module.network.adminserver_nsg_id, null)
}

output "fss_nsg_id" {
  description = "Network Security Group for File Storage Service resources."
  value       = try(module.network.fss_nsg_id, null)
}

output "network_security_rules" {
  value = var.output_detail ? try(module.network.network_security_rules, null) : null
}

# LPG
output "lpg_all_attributes" {
  description = "all attributes of created lpg"
  value       = try(one(module.vcn[*].lpg_all_attributes), null)
}