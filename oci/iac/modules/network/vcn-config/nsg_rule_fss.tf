# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

## Ingress Rules
resource "oci_core_network_security_group_security_rule" "fss_ingress_security_rule_1" {
  for_each = {
  for nsg_name, nsg_id in var.nsg_ids :
  nsg_name => nsg_id if nsg_name == "mount_target_nsg_id" && var.add_fss && var.existing_mt_subnet_id == "" && !var.add_existing_mount_target && !var.add_existing_fss
  }
  network_security_group_id = element(each.value, 0)
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 2050
      min = 2048
    }
  }
}

resource "oci_core_network_security_group_security_rule" "fss_ingress_security_rule_2" {
  for_each = {
  for nsg_name, nsg_id in var.nsg_ids :
  nsg_name => nsg_id if nsg_name == "mount_target_nsg_id" && var.add_fss && var.existing_mt_subnet_id == "" && !var.add_existing_mount_target && !var.add_existing_fss
  }
  network_security_group_id = element(each.value, 0)
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 111
      min = 111
    }
  }
}

resource "oci_core_network_security_group_security_rule" "fss_ingress_security_rule_3" {
  for_each = {
  for nsg_name, nsg_id in var.nsg_ids :
  nsg_name => nsg_id if nsg_name == "mount_target_nsg_id" && var.add_fss && var.existing_mt_subnet_id == "" && !var.add_existing_mount_target && !var.add_existing_fss
  }
  network_security_group_id = element(each.value, 0)
  direction                 = "INGRESS"
  protocol                  = "17"

  source      = var.vcn_cidr
  source_type = "CIDR_BLOCK"
  stateless   = false

  udp_options {
    destination_port_range {
      max = 2048
      min = 2048
    }
  }
}

resource "oci_core_network_security_group_security_rule" "fss_ingress_security_rule_4" {
  for_each = {
  for nsg_name, nsg_id in var.nsg_ids :
  nsg_name => nsg_id if nsg_name == "mount_target_nsg_id" && var.add_fss && var.existing_mt_subnet_id == "" && !var.add_existing_mount_target && !var.add_existing_fss
  }
  network_security_group_id = element(each.value, 0)
  direction                 = "INGRESS"
  protocol                  = "17"

  source      = var.wls_subnet_cidr
  source_type = "CIDR_BLOCK"
  stateless   = false

  udp_options {
    destination_port_range {
      max = 111
      min = 111
    }
  }
}

## Egress Rules
resource "oci_core_network_security_group_security_rule" "fss_egress_security_rule_1" {
  for_each = {
  for nsg_name, nsg_id in var.nsg_ids :
  nsg_name => nsg_id if nsg_name == "mount_target_nsg_id" && var.add_fss && var.existing_mt_subnet_id == "" && !var.add_existing_mount_target && !var.add_existing_fss
  }
  network_security_group_id = element(each.value, 0)
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = var.vcn_cidr
  destination_type = "CIDR_BLOCK"
  stateless        = false

  tcp_options {
    source_port_range {
      max = 2050
      min = 2048
    }
  }
}

resource "oci_core_network_security_group_security_rule" "fss_egress_security_rule_2" {
  for_each = {
  for nsg_name, nsg_id in var.nsg_ids :
  nsg_name => nsg_id if nsg_name == "mount_target_nsg_id" && var.add_fss && var.existing_mt_subnet_id == "" && !var.add_existing_mount_target && !var.add_existing_fss
  }
  network_security_group_id = element(each.value, 0)
  direction                 = "EGRESS"
  protocol                  = "6"

  destination      = var.vcn_cidr
  destination_type = "CIDR_BLOCK"
  stateless        = false

  tcp_options {
    source_port_range {
      max = 111
      min = 111
    }
  }
}

resource "oci_core_network_security_group_security_rule" "fss_egress_security_rule_3" {
  for_each = {
  for nsg_name, nsg_id in var.nsg_ids :
  nsg_name => nsg_id if nsg_name == "mount_target_nsg_id" && var.add_fss && var.existing_mt_subnet_id == "" && !var.add_existing_mount_target && !var.add_existing_fss
  }
  network_security_group_id = element(each.value, 0)
  direction                 = "EGRESS"
  protocol                  = "17"

  destination      = var.vcn_cidr
  destination_type = "CIDR_BLOCK"
  stateless        = false

  udp_options {
    source_port_range {
      max = 111
      min = 111
    }
  }
}


#
#locals {
#  fss_nsg_config = try(var.nsgs.fss, { create = "never" })
#  fss_nsg_create = coalesce(lookup(local.fss_nsg_config, "create", null), "auto")
#  fss_nsg_enabled = anytrue([
#    local.fss_nsg_create == "always",
#    alltrue([
#      local.fss_nsg_create == "auto",
#      coalesce(lookup(local.fss_nsg_config, "id", null), "none") == "none",
#      var.create_cluster,
#    ]),
#  ])
#  # Return provided NSG when configured with an existing ID or created resource ID
#  fss_nsg_id = one(compact([try(var.nsgs.fss.id, null), one(oci_core_network_security_group.fss[*].id)]))
#  fss_rules = local.fss_nsg_enabled ? {
#    # See https://docs.oracle.com/en-us/iaas/Content/File/Tasks/securitylistsfilestorage.htm
#    # Ingress
#    "Allow UDP ingress for NFS portmapper from workers" : {
#      protocol = local.udp_protocol, port = local.fss_nfs_portmapper_port, source = local.worker_nsg_id, source_type = local.rule_type_nsg,
#    },
#    "Allow TCP ingress for NFS portmapper from workers" : {
#      protocol = local.tcp_protocol, port = local.fss_nfs_portmapper_port, source = local.worker_nsg_id, source_type = local.rule_type_nsg,
#    },
#    "Allow UDP ingress for NFS from workers" : {
#      protocol = local.udp_protocol, port = local.fss_nfs_port_min, source = local.worker_nsg_id, source_type = local.rule_type_nsg,
#    },
#    "Allow TCP ingress for NFS from workers" : {
#      protocol = local.tcp_protocol, port_min = local.node_port_min, port_max = local.node_port_max, source = local.worker_nsg_id, source_type = local.rule_type_nsg,
#    },
#
#    # Egress
#    "Allow UDP egress for NFS portmapper to workers" : {
#      protocol = local.udp_protocol, port = local.fss_nfs_portmapper_port, destination = local.worker_nsg_id, destination_type = local.rule_type_nsg,
#    },
#    "Allow TCP egress for NFS portmapper to workers" : {
#      protocol = local.tcp_protocol, port = local.fss_nfs_portmapper_port, destination = local.worker_nsg_id, destination_type = local.rule_type_nsg,
#    },
#    "Allow TCP egress for NFS to workers" : {
#      protocol = local.tcp_protocol, port_min = local.node_port_min, port_max = local.node_port_max, destination = local.worker_nsg_id, destination_type = local.rule_type_nsg,
#    },
#  } : {}
#}
#
#resource "oci_core_network_security_group" "fss" {
#  count          = local.fss_nsg_enabled ? 1 : 0
#  compartment_id = var.compartment_id
#  display_name   = "fss-${var.state_id}"
#  vcn_id         = var.vcn_id
#  defined_tags   = var.tags.defined_tags
#  freeform_tags  = var.tags.freeform_tags
#  lifecycle {
#    ignore_changes = [defined_tags, freeform_tags, display_name]
#  }
#}
#
#output "fss_nsg_id" {
#  value = local.fss_nsg_id
#}
