# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {
  ms_sciders=var.wls_ms_source_cidrs
  ms_port_list=var.wls_managed_server_ports
  ms_nsg_id = element(var.nsg_ids["managed_nsg_id"], 0)
  ms_ports_ciders = merge([
      for scider in local.ms_sciders : {
          for port in local.ms_port_list :
          "Allow ingress to Managed Server on Port ${port}" =>
          {
            protocol    = local.tcp_protocol,
            port        = port,
            source      = scider,
            source_type = local.rule_type_cidr,
          }
      }
  ]...)

  ms_rules  = merge(
    local.ms_ports_ciders,
    {
      "Allow SSH ingress to WLS Managed Servers from Bastion" : {
        protocol    = local.tcp_protocol, port = local.ssh_port, source = var.bastion_subnet_cidr,
        source_type = local.rule_type_cidr,
      },
    })
  # Dynamic map of all NSG rules for enabled NSGs
    ms_all_rules = { for x, y in merge(
      { for k, v in local.ms_rules : k => merge(v, { "nsg_id" = local.ms_nsg_id }) },
    ) : x => merge(y, {
      description               = x
      network_security_group_id = lookup(y, "nsg_id")
      direction                 = contains(keys(y), "source") ? "INGRESS" : "EGRESS"
      protocol                  = lookup(y, "protocol")
      source                    = lookup(y, "source", null)
      source_type               = lookup(y, "source_type", null)
      destination               = lookup(y, "destination", null)
      destination_type          = lookup(y, "destination_type", null)
    }) }

}

resource "oci_core_network_security_group_security_rule" "wls_public_ingress_security_rule" {
  for_each                  = local.ms_all_rules
  stateless                 = false
  description               = each.value.description
  destination               = each.value.destination
  destination_type          = each.value.destination_type
  direction                 = each.value.direction
  network_security_group_id = each.value.network_security_group_id
  protocol                  = each.value.protocol
  source                    = each.value.source
  source_type               = each.value.source_type

  dynamic "tcp_options" {
    for_each = (tostring(each.value.protocol) == tostring(local.tcp_protocol) &&
    tonumber(lookup(each.value, "port", 0)) != local.all_ports ? [each.value] : []
    )
    content {
      destination_port_range {
        min = tonumber(lookup(tcp_options.value, "port_min", lookup(tcp_options.value, "port", 0)))
        max = tonumber(lookup(tcp_options.value, "port_max", lookup(tcp_options.value, "port", 0)))
      }
    }
  }

  dynamic "udp_options" {
    for_each = (tostring(each.value.protocol) == tostring(local.udp_protocol) &&
    tonumber(lookup(each.value, "port", 0)) != local.all_ports ? [each.value] : []
    )
    content {
      destination_port_range {
        min = tonumber(lookup(udp_options.value, "port_min", lookup(udp_options.value, "port", 0)))
        max = tonumber(lookup(udp_options.value, "port_max", lookup(udp_options.value, "port", 0)))
      }
    }
  }

  dynamic "icmp_options" {
    for_each = tostring(each.value.protocol) == tostring(local.icmp_protocol) ? [1] : []
    content {
      type = 3
      code = 4
    }
  }

  lifecycle {
    precondition {
      condition = tostring(each.value.protocol) == tostring(local.icmp_protocol) || contains(keys(each.value), "port") || (
      contains(keys(each.value), "port_min") && contains(keys(each.value), "port_max")
      )
      error_message = "TCP/UDP rule must contain a port or port range: '${each.key}'"
    }

    precondition {
      condition = (
      tostring(each.value.protocol) == tostring(local.icmp_protocol)
      || can(tonumber(each.value.port))
      || (can(tonumber(each.value.port_min)) && can(tonumber(each.value.port_max)))
      )

      error_message = "TCP/UDP ports must be numeric: '${each.key}'"
    }

    precondition {
      condition     = each.value.direction == "EGRESS" || coalesce(each.value.source, "none") != "none"
      error_message = "Ingress rule must have a source: '${each.key}'"
    }

    precondition {
      condition     = each.value.direction == "INGRESS" || coalesce(each.value.destination, "none") != "none"
      error_message = "Egress rule must have a destination: '${each.key}'"
    }

    # Extra precaution against unexpected allow-all ingress rules created by the module
    # Generated rules will produce errors unless any of the follow conditions are true
    precondition {
      condition = anytrue([
        tostring(each.value.protocol) == tostring(local.icmp_protocol), # Traffic is ICMP
        each.value.direction == "EGRESS",                               # Traffic is outbound
        each.value.source != local.anywhere,                            # Rule does not allow all traffic

        # SSH ingress to managed servers from anywhere has been configured explicitly
        alltrue([
          tonumber(lookup(each.value, "port", 0)) == local.ssh_port,
          contains(var.wls_ms_source_cidrs, local.anywhere),
        ]),

      ])
      error_message = "Unexpected open ingress rule: ${each.key}"
    }
  }
}

#resource "oci_core_network_security_group_security_rule" "wls_public_ingress_security_rule" {
#  count = var.assign_backend_public_ip ? 1 : 0
#
#  network_security_group_id = element(var.nsg_ids["managed_nsg_id"], 0)
#  direction                 = "INGRESS"
#  protocol                  = "6"
#
#
#  source      = local.anywhere
#  source_type = local.rule_type_cidr
#  stateless   = false
#
#  tcp_options {
#    destination_port_range {
#      max = 22
#      min = 22
#    }
#  }
#}

resource "oci_core_network_security_group_security_rule" "wls_ingress_internal_security_rule" {

  network_security_group_id = element(var.nsg_ids["managed_nsg_id"], 0)
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.wls_subnet_cidr
  source_type = local.rule_type_cidr
  stateless   = false
}


#resource "oci_core_network_security_group_security_rule" "wls_ingress_app_ms_security_rule" {
#  count                     = length(var.wls_ms_source_cidrs) > 0 ? length(var.wls_ms_source_cidrs) : 0
#  network_security_group_id = element(var.nsg_ids["managed_nsg_id"], 0)
#  direction                 = "INGRESS"
#  protocol                  = "6"
#
#  source      = var.wls_ms_source_cidrs[count.index]
#  source_type = local.rule_type_cidr
#  stateless   = false
#
#  tcp_options {
#    destination_port_range {
#      min = var.wls_ms_content_port
#      max = var.wls_ms_content_port
#    }
#  }
#}
#TODO: change to dynamic list.
#####################################################################################
# Bastion with Managed Server  rules
#####################################################################################
resource "oci_core_network_security_group_security_rule" "wls_bastion_ingress_security_rule" {
  count                     = var.existing_bastion_instance_id == "" && var.is_bastion_instance_required && !var.assign_backend_public_ip ? 1 : 0
  network_security_group_id = element(var.nsg_ids["managed_nsg_id"], 0)
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.bastion_subnet_cidr
  source_type = local.rule_type_cidr
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 22
      min = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "wls_existing_bastion_ingress_security_rule" {
  count                     = var.existing_bastion_instance_id != "" && var.is_bastion_instance_required && !var.assign_backend_public_ip ? 1 : 0
  network_security_group_id = element(var.nsg_ids["managed_nsg_id"], 0)
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = format("%s/32", data.oci_core_instance.existing_bastion_instance[count.index].private_ip)
  source_type = local.rule_type_cidr
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 22
      min = 22
    }
  }
}

output "ms_nsg_id" {
  value = local.ms_nsg_id
}

