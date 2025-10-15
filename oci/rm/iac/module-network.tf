# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

data "oci_core_vcn" "oke" {
  count  = var.create_vcn ? 0 : 1
  vcn_id = coalesce(var.vcn_id, "none")
}

data "oci_core_services" "all_services" {
  filter {
    name   = "cidr_block"
    values = ["all-.*-services-in-oracle-services-network"]
    regex  = true
  }
}

# ──────────────────────────────────────────────────────────
# Datasource to Fetch any existing gateways on the chosen VCN
data "oci_core_internet_gateways" "existing_igs" {
  count          = var.create_vcn ? 0 : 1
  compartment_id = var.network_compartment_id
  vcn_id         = var.vcn_id
}

data "oci_core_nat_gateways" "existing_ngs" {
  count          = var.create_vcn ? 0 : 1
  compartment_id = var.network_compartment_id
  vcn_id         = var.vcn_id
}

data "oci_core_service_gateways" "existing_sgs" {
  count          = var.create_vcn ? 0 : 1
  compartment_id = var.network_compartment_id
  vcn_id         = var.vcn_id
}

locals {
  # Created VCN if enabled, else var.vcn_id
  vcn_id = var.create_vcn ? try(one(module.vcn[*].vcn_id), var.vcn_id) : var.vcn_id

  # Only create in case of existing VCN if none of the gateways already exist
  create_ig = var.create_vcn ? false : try(length(data.oci_core_internet_gateways.existing_igs[0].gateways), 0) == 0
  create_ng = var.create_vcn ? false : try(length(data.oci_core_nat_gateways.existing_ngs[0].nat_gateways), 0) == 0
  create_sg = var.create_vcn ? false : try(length(data.oci_core_service_gateways.existing_sgs[0].service_gateways), 0) == 0

  # In case the gateways exists in the existing VCN, then fetch the gateways id to create new route tables using those ids.
  ig_exists = !var.create_vcn && !local.create_ig
  ng_exists = !var.create_vcn && !local.create_ng
  sg_exists = !var.create_vcn && !local.create_sg

  # Fetch the existing gateway ID of each type.
  # This is because OCI allows only one gateway of each type (Internet, NAT, Service) per VCN.
  # Therefore, if any exist, the first entry is guaranteed to be the one used in the VCN.

  ig_fetched_id = local.ig_exists ? try(data.oci_core_internet_gateways.existing_igs[0].gateways[0].id, "") : ""
  ng_fetched_id = local.ng_exists ? try(data.oci_core_nat_gateways.existing_ngs[0].nat_gateways[0].id, "") : ""
  sg_fetched_id = local.sg_exists ? try(data.oci_core_service_gateways.existing_sgs[0].service_gateways[0].id, "") : ""
  # ──────────────────────────────────────────────────────────

  # Configured VCN CIDRs if creating, else from provided vcn_id
  vcn_lookup             = coalesce(one(data.oci_core_vcn.oke[*].cidr_blocks), [])
  vcn_lookup_cidr_blocks = flatten(local.vcn_lookup)
  vcn_cidrs              = var.create_vcn ? var.vcn_cidrs : local.vcn_lookup_cidr_blocks

  # Created route table if enabled, else var.ig_route_table_id
  ig_route_table_id = var.create_vcn ? try(one(module.vcn[*].ig_route_id), var.ig_route_table_id) : try(oci_core_route_table.ig_rt[0].id, var.ig_route_table_id)

  # Created route table if enabled, else var.nat_route_table_id
  nat_route_table_id = var.create_vcn ? try(one(module.vcn[*].nat_route_id), var.nat_route_table_id) : try(oci_core_route_table.nat_rt[0].id, var.nat_route_table_id)

  network_compartment_id = var.network_compartment_id == "" ? var.compartment_ocid : var.network_compartment_id
  # Map of configured subnets to specified/generated dns_label when enabled
  # If `assign_dns = true`, use the provided `dns_label` for each subnet (if specified),
  # otherwise use "<two characters of subnet key><state_id>" as the default DNS label to ensure uniqueness.
  subnet_dns_labels = { for k, v in var.subnets :
    k => coalesce(lookup(v, "dns_label", null), "${substr(k, 0, 2)}${local.state_id}")
    if var.assign_dns
  }

  dblpg_ids_map = module.lpg[*].dblpg_ids
  wlslpg_ids_map = module.lpg[*].wlslpg_ids

  # Create JSON strings for metadata
  db_lpg_ids  = jsonencode(local.dblpg_ids_map)
  wls_lpg_ids = jsonencode(local.wlslpg_ids_map)

  db_subnet_ids = jsonencode(
    var.datasources != null ? {
      for k, v in var.datasources :
      k => (
      v.is_vcn_peering ? v.db_subnet_id : null
      )
    } : {}
  )

  is_vcn_peering = var.datasources == null ? false : anytrue([for _, v in var.datasources : v.is_vcn_peering])
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
    var.vcn_create_nat_gateway != "never",    # always disable
    anytrue([                                 # enable for configurations that generally utilize it
      var.vcn_create_nat_gateway == "always", # always enable
      !var.wlsserver_is_public,               # enable for private wlsservers
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

locals {
  vcn_name = coalesce(var.vcn_name, "wls-${local.state_id}")
}

# Creates the gateways and route tables in case of existing VCN

########################
# Internet Gateway (IGW)
########################

resource "oci_core_internet_gateway" "ig" {
  count          = local.create_ig ? 1 : 0
  compartment_id = var.network_compartment_id
  vcn_id         = local.vcn_id
  display_name   = "${local.vcn_name}-ig"

}

resource "oci_core_route_table" "ig_rt" {
  # always create the route table; it will point to either new or existing IG
  count = var.create_vcn ? 0 : 1

  compartment_id = var.network_compartment_id
  vcn_id         = local.vcn_id
  display_name   = "${local.vcn_name}-internet-route"

  # Must use a block form, not an argument
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = local.ig_exists ? local.ig_fetched_id : oci_core_internet_gateway.ig[0].id
  }

}

#######################
# Service Gateway (SGW)
#######################

resource "oci_core_service_gateway" "sg" {
  count          = local.create_sg ? 1 : 0
  compartment_id = var.network_compartment_id
  vcn_id         = local.vcn_id
  display_name   = "${local.vcn_name}-sg"

  services {
    service_id = data.oci_core_services.all_services.services.0.id
  }
}

resource "oci_core_route_table" "sg_rt" {
  # always create the route table; it will point to either new or existing IG
  count          = var.create_vcn ? 0 : 1
  compartment_id = var.network_compartment_id
  vcn_id         = local.vcn_id
  display_name   = "${local.vcn_name}-sg-routetable"

  route_rules {
    destination       = data.oci_core_services.all_services.services.0.cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = local.sg_exists ? local.sg_fetched_id : oci_core_service_gateway.sg[0].id
  }
}

###################
# NAT Gateway (NGW)
###################

resource "oci_core_nat_gateway" "nat_gateway" {
  count          = local.create_ng ? 1 : 0
  compartment_id = var.network_compartment_id
  vcn_id         = local.vcn_id
  display_name   = "${local.vcn_name}-ng"

  public_ip_id = var.nat_gateway_public_ip_id != "none" ? var.nat_gateway_public_ip_id : null

}

resource "oci_core_route_table" "nat_rt" {
  # always create the route table; it will point to either new or existing IG
  count = var.create_vcn ? 0 : 1

  compartment_id = var.network_compartment_id
  vcn_id         = local.vcn_id
  display_name   = "${local.vcn_name}-nat-routetable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = local.ng_exists ? local.ng_fetched_id : oci_core_nat_gateway.nat_gateway[0].id
    description       = "Terraformed - Auto-generated at NAT Gateway creation: NAT Gateway as default gateway"
  }

  dynamic "route_rules" {
    # * If Service Gateway is created with the module, automatically creates a rule to handle traffic for "all services" through Service Gateway
    for_each = var.create_vcn ? [] : [1]
    content {
      destination       = data.oci_core_services.all_services.services.0.cidr_block
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = local.sg_exists ? local.sg_fetched_id : oci_core_service_gateway.sg[0].id
      description       = "Terraformed - Auto-generated at Service Gateway creation: All Services in region to Service Gateway"
    }
  }
}

/* Create back end  private subnet for wls */
module "network-wls-private-subnet" {
  source             = "./modules/network/subnet"
  compartment_id     = local.network_compartment_id
  vcn_id             = local.vcn_id
  route_table_id     = local.ng_exists ? oci_core_route_table.nat_rt[0].id : local.nat_route_table_id
  subnet_name        = format("wlsservers-%v", local.state_id)
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

/* Create back end subnet for bastion subnet */
module "network_bastion_subnet" {
  source             = "./modules/network/subnet"
  count              = var.create_bastion ? 1 : 0
  compartment_id     = local.network_compartment_id
  vcn_id             = local.vcn_id
  route_table_id     = local.ig_route_table_id
  subnet_name        = format("bastion-%v", local.state_id)
  dns_label          = lookup(local.subnet_dns_labels, "bastion", null)
  cidr_block         = var.bastion_subnet_cidr
  prohibit_public_ip = false

  # Standard tags as defined if enabled for use, or freeform
  # User-provided tags are merged last and take precedence
  defined_tags = merge(var.use_defined_tags ? {
    "${var.tag_namespace}.state_id" = local.state_id,
    "${var.tag_namespace}.role"     = "bastion",
  } : {}, local.bastion_defined_tags)
  freeform_tags = merge(var.use_defined_tags ? {} : {
    "state_id" = local.state_id,
    "role"     = "bastion",
  }, local.bastion_freeform_tags)
}

/* Create back end subnet for public loadbalancer subnet */
module "network_pub_lb_subnet" {
  source             = "./modules/network/subnet"
  count              = var.add_load_balancer? 1 : 0

  compartment_id     = local.network_compartment_id
  vcn_id             = local.vcn_id
  route_table_id     = local.ig_route_table_id
  subnet_name        = format("public-lb-%v", local.state_id)
  dns_label          = lookup(local.subnet_dns_labels, "pub_lb", null)
  cidr_block         = var.pub_lb_subnet_cidr
  prohibit_public_ip = false

  defined_tags = merge(var.use_defined_tags ? {
    "${var.tag_namespace}.state_id" = local.state_id,
    "${var.tag_namespace}.role"     = "pub_lb",
  } : {}, local.service_lb_defined_tags)

  freeform_tags = merge(var.use_defined_tags ? {} : {
    "state_id" = local.state_id,
    "role"     = "pub_lb",
  }, local.service_lb_freeform_tags)
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
  allow_rules_public_lb             = var.allow_rules_public_lb
  allow_rules_wlsservers            = var.allow_rules_wlsservers
  allow_rules_adminserver           = var.allow_rules_adminserver
  allow_adminserver_internet_access = var.allow_adminserver_internet_access
  allow_adminserver_ssh_access      = var.allow_adminserver_ssh_access
  allow_wlsserver_internet_access   = var.allow_wlsservers_internet_access
  allow_wlsserver_ssh_access        = var.allow_wlsservers_ssh_access
  allow_bastion_domain_access       = var.allow_bastion_domain_access
  allow_bastion_adminserver_access  = var.allow_bastion_adminserver_access
  wls_admin_console_port            = local.wls_admin_conole_port
  assign_dns                        = var.assign_dns
  bastion_allowed_cidrs             = var.bastion_allowed_cidrs
  bastion_is_public                 = var.bastion_is_public
  create_bastion                    = var.create_bastion
  nsgs                              = var.nsgs
  add_load_balancer                 = var.add_load_balancer
  #  create_operator              = false            #future use
  enable_waf           = false #future use
  ig_route_table_id    = local.ig_exists ? oci_core_route_table.ig_rt[0].id : local.ig_route_table_id
  load_balancers       = var.load_balancers
  nat_route_table_id   = local.nat_route_table_id
  subnets              = var.subnets
  vcn_cidrs            = local.vcn_cidrs
  vcn_id               = local.vcn_id
  nm_ports             = local.nm_ports
  wlsserver_is_public  = var.wlsserver_is_public
  wlsserver_ports      = local.wls_domain_all_discovered_ports
  adminserver_ports    = local.wls_admin_server_ports
  resource_name_prefix = local.wls_domain_name
  backend_ports        = local.wls_all_ports_application_traffic_servers
  pub_lb_subnet_cidr_value = try(var.pub_lb_subnet_cidr, null)
}

/* Create LPGs for VCN Peering */
module "lpg" {
  count                     = var.datasources != null && local.is_vcn_peering ? 1 : 0
  source                    = "./modules/network/vcn-peering"
  compartment_id            = local.network_compartment_id
  vcn_id                    = local.vcn_id
  wlsserver_subnet_id       = try(module.network-wls-private-subnet.subnet_id, "")
  lpg_name                  = format("lpg-%v", local.state_id)
  datasources               = var.datasources
}

module "dns" {
  source                     = "./modules/network/dns"
  depends_on                 = [module.wlsservers]
  secondary_nodes_IPs        = one(module.wlsservers[*].wlsserver_private_ips)
  wlsserver_vcn_id           = local.vcn_id
  compartment_id             = local.network_compartment_id
  wls_data                   = var.wls_inventory_data
  wlsserver_count_expected   = coalesce(one(module.wlsservers[*].wlsserver_count_expected), 0)
  source_nodes               = one(module.wlsservers[*].wlsserver_hostnames)
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
  value = try(module.network_bastion_subnet[0].subnet_id, null)
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
  value = try(module.network-wls-private-subnet.subnet_id, null)
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
  value = try(module.network_pub_lb_subnet[0].subnet_id, null)
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

output "adminserver_port" {
  description = "Port of admin node"
  value       = local.wls_admin_conole_port
}
