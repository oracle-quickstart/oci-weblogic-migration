# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


module "load-balancer" {
  #depends_on = [module.network-validation]
  source = "./modules/lb/loadbalancer"
  count  = (local.add_load_balancer && var.existing_load_balancer_id == "") ? 1 : 0

  compartment_id           = local.network_compartment_id
  lb_reserved_public_ip_id = compact([var.lb_reserved_public_ip_id])
  is_lb_private            = var.is_lb_private
  lb_nsg_id                = var.lb_subnet_1_id != "" ? (var.add_existing_nsg ? [var.existing_lb_nsg_id] : []) : element(module.network-lb-nsg[*].nsg_id, 0)
  lb_max_bandwidth         = var.lb_max_bandwidth
  lb_min_bandwidth         = var.lb_min_bandwidth
  lb_name                  = "${local.service_name_prefix}-lb"
  lb_subnet_1_id           = var.lb_subnet_1_id != "" ? [var.lb_subnet_1_id] : [module.network-lb-subnet-1[0].subnet_id]
  lb_subnet_2_id           = [var.lb_subnet_2_id]

  tags = {
    defined_tags  = local.defined_tags
    freeform_tags = local.free_form_tags
  }
}