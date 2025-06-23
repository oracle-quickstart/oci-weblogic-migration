# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  bastion_nsg_config = try(var.nsgs.bastion, { create = "never" })
  bastion_nsg_create = coalesce(lookup(local.bastion_nsg_config, "create", null), "auto")
  bastion_nsg_enabled = var.create_bastion && anytrue([
    local.bastion_nsg_create == "always",
    alltrue([
      local.bastion_nsg_create == "auto",
      coalesce(lookup(local.bastion_nsg_config, "id", null), "none") == "none",
    ]),
  ])
  # Return provided NSG when configured with an existing ID or created resource ID
  bastion_nsg_id = one(compact([try(var.nsgs.bastion.id, null), one(oci_core_network_security_group.bastion[*].id)]))
  bastion_rules = local.bastion_nsg_enabled ? merge(
    { for cidr in var.bastion_allowed_cidrs :
      "Allow SSH ingress to bastion from ${cidr}" => {
        protocol = local.tcp_protocol, port = local.ssh_port, source = cidr, source_type = local.rule_type_cidr,
      }
    },
    {
      "Allow TCP egress from bastion to OCI services" : {
        protocol = local.tcp_protocol, port = local.all_ports, destination = local.osn, destination_type = local.rule_type_service,
      },
    },
    var.allow_wlsserver_ssh_access && local.wlsserver_nsg_enabled ? {
      "Allow SSH egress from bastion to wlsservers" = {
        protocol = local.tcp_protocol, port = local.ssh_port, destination = local.wlsserver_nsg_id, destination_type = local.rule_type_nsg,
      },
    }:{},
    var.allow_adminserver_ssh_access && local.adminserver_nsg_enabled ? {
      "Allow SSH egress from bastion to adminservers" = {
        protocol = local.tcp_protocol, port = local.ssh_port, destination = local.adminserver_nsg_id, destination_type = local.rule_type_nsg,
      },
    }: {},
    var.allow_bastion_domain_access && var.bastion_is_public ? {
      "Allow ALL egress from bastion to Internet" = {
        protocol = local.all_protocols, port = local.all_ports, destination = local.anywhere, destination_type = local.rule_type_cidr,
      },
    } : {},
  ) : {}
}


resource "oci_core_network_security_group" "bastion" {
  count          = local.bastion_nsg_enabled ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "bastion-${var.state_id}"
  vcn_id         = var.vcn_id
  defined_tags   = var.defined_tags
  freeform_tags  = var.freeform_tags
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags, display_name, vcn_id]
  }
}

output "bastion_nsg_id" {
  value = local.bastion_nsg_id
}
