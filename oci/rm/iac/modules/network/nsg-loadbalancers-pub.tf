# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  pub_lb_nsg_config = try(var.nsgs.pub_lb, { create = "never" })
  pub_lb_nsg_create = coalesce(lookup(local.pub_lb_nsg_config, "create", null), "auto")
  pub_lb_nsg_enabled = var.add_load_balancer && anytrue([
    local.pub_lb_nsg_create == "always",
    alltrue([
      local.pub_lb_nsg_create == "auto",
      coalesce(lookup(local.pub_lb_nsg_config, "id", null), "none") == "none",
      var.load_balancers == "public" || var.load_balancers == "both",
    ]),
  ])
  # Return provided NSG when configured with an existing ID or created resource ID
  pub_lb_nsg_id = one(compact([try(var.nsgs.pub_lb.id, null), one(oci_core_network_security_group.pub_lb[*].id)]))
  pub_lb_rules = local.pub_lb_nsg_enabled ? merge(
    {
      "Allow all egress traffic from public load balancer" : { protocol = local.all_protocols, destination = local.anywhere, destination_type = local.rule_type_cidr, port = 0,
      },
    },
    var.enable_waf ? local.waf_rules : {},
    var.allow_rules_public_lb,
  ) : {}
}

resource "oci_core_network_security_group" "pub_lb" {
  count          = local.pub_lb_nsg_enabled ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.resource_name_prefix}-pub_lb-${var.state_id}"
  vcn_id         = var.vcn_id
  defined_tags   = var.defined_tags
  freeform_tags  = var.freeform_tags
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags, display_name, vcn_id]
  }
}

output "pub_lb_nsg_id" {
  value = local.pub_lb_nsg_id
}
