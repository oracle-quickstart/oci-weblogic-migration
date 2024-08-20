# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_load_balancer_load_balancers" "existing_load_balancers_data_source" {
  compartment_id = coalesce(var.network_compartment_id, local.compartment_id)
}

locals{
  #  # Add a load balancer if
  #  # - User explicitly says he wants a load balancer, or
  #  # - User selects IDCS, because IDCS requires a load balancer
    add_load_balancer = var.add_load_balancer
    existent_load_balancer =  coalesce(var.existing_load_balancer_id,"none") != "none"
    new_lb_ip                  = "" #!local.add_load_balancer || local.use_existing_lb ? "" : element(coalescelist(module.load-balancer[0].wls_loadbalancer_ip_addresses, [""]), 0)
    new_lb_id                  = "" #element(concat(module.load-balancer[*].wls_loadbalancer_id, [""]), 0)
    existing_lb_ip             = local.use_existing_lb && local.valid_existing_lb ? local.existing_lb_object_as_list[0].ip_addresses[0] : ""
    existing_lb_object_as_list = local.use_existing_lb ? [for lb in data.oci_load_balancer_load_balancers.existing_load_balancers_data_source.load_balancers[*] : lb if lb.id == var.existing_load_balancer_id] : []
    valid_existing_lb          = length(local.existing_lb_object_as_list) == 1
    use_existing_lb            = local.add_load_balancer && local.existent_load_balancer
    lb_backendset_name         = local.use_existing_lb ? var.backendset_name_for_existing_load_balancer : format("%s-%v-lb-backendset",local.wls_domain_name,local.state_id)
}


module "load-balancer" {
  #depends_on = [module.network-validation]
  source = "./modules/lb/loadbalancer"
  count  = (local.add_load_balancer && ! local.existent_load_balancer ) ? 1 : 0

  compartment_id           = coalesce(var.network_compartment_id, local.compartment_id)
  lb_reserved_public_ip_id = compact([var.lb_reserved_public_ip_id])
  is_lb_private            = false #var.is_lb_private
#  lb_nsg_id                = var.lb_subnet_1_id != "" ? (var.add_existing_nsg ? [var.existing_lb_nsg_id] : []) : element(module.network-lb-nsg[*].nsg_id, 0)
  lb_nsg_id                 = module.network.pub_lb_nsg_id
  lb_max_bandwidth         = var.lb_max_bandwidth
  lb_min_bandwidth         = var.lb_min_bandwidth
  lb_name                  = format("%s-%v-lb",local.wls_domain_name,local.state_id)
#  lb_subnet_1_id           = var.lb_subnet_1_id != "" ? [var.lb_subnet_1_id] : [module.network-lb-subnet-1[0].subnet_id]
#  lb_subnet_2_id           = [var.lb_subnet_2_id]
  lb_subnet_id = [module.network.pub_lb_subnet_id]
  state_id            = local.state_id

  # Tagging
  tag_namespace    = var.tag_namespace
  use_defined_tags = var.use_defined_tags
  defined_tags  = local.service_lb_defined_tags
  freeform_tags = local.service_lb_freeform_tags

}

module "load-balancer-backends" {
  #depends_on = [module.network-validation]
  source = "./modules/lb/backends"
  count  = local.add_load_balancer ? 1 : 0

  state_id            = local.state_id
  load_balancer_id     = local.add_load_balancer ? (! local.existent_load_balancer ? var.existing_load_balancer_id : one(coalescelist(module.load-balancer[*].wls_loadbalancer_id, [""]))) : null
  use_existing_lb      = local.use_existing_lb
  lb_backendset_name   = local.lb_backendset_name
  #TODO: JOI remove
  #  num_vm_instances     = var.wls_node_count
  #  num_vm_instances     = 0
  instance_private_ips = try(one(module.wlsservers[*].wlsserver_pool_ips), null)
  health_check_url     = "/"
  resource_name_prefix = local.wls_domain_name
  backend_instance_ports = local.lb_backends_to_map
}