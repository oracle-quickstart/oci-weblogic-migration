# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

resource "oci_load_balancer_load_balancer" "wls_loadbalancer" {

  shape          = var.lb_shape
  compartment_id = var.compartment_id

  subnet_ids = compact(
    concat(
      compact(var.lb_subnet_id)
    )
  )
  dynamic "shape_details" {
    for_each = length(regexall("flex", var.lb_shape)) > 0 ? [1] : []
    content {
          maximum_bandwidth_in_mbps = var.lb_max_bandwidth
          minimum_bandwidth_in_mbps = var.lb_min_bandwidth
    }
  }

#  shape_details {
#    #Required
#    maximum_bandwidth_in_mbps = var.lb_max_bandwidth
#    minimum_bandwidth_in_mbps = var.lb_min_bandwidth
#  }
  display_name               = var.lb_name
  is_private                 = var.is_lb_private
  network_security_group_ids = var.lb_nsg_id
  defined_tags               = var.defined_tags
  freeform_tags              = var.freeform_tags


  dynamic "reserved_ips" {
    for_each = var.lb_reserved_public_ip_id
    content {
      id = reserved_ips.value
    }
  }

  lifecycle {
    ignore_changes = [
      defined_tags, freeform_tags, display_name
    ]

    precondition {
      condition     = coalescelist(var.lb_subnet_id, []) != []
      error_message = "Missing lb_subnet_id for Loadbalancer. Check provided value for lb_subnet_id"
    }
  }
}
