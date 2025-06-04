# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_load_balancer_load_balancers" "existing_load_balancers_data_source" {
  compartment_id = coalesce(var.network_compartment_id, local.compartment_id)
}

locals{
  #  # Add a load balancer if
  #  # - User explicitly says he wants a load balancer
    add_load_balancer = var.add_load_balancer
    existent_load_balancer =  coalesce(var.existing_load_balancer_id,"none") != "none"
    new_lb_ip                  = "" #!local.add_load_balancer || local.use_existing_lb ? "" : element(coalescelist(module.load-balancer[0].wls_loadbalancer_ip_addresses, [""]), 0)
    new_lb_id                  = "" #element(concat(module.load-balancer[*].wls_loadbalancer_id, [""]), 0)
    existing_lb_ip             = local.use_existing_lb && local.valid_existing_lb ? local.existing_lb_object_as_list[0].ip_addresses[0] : ""
    existing_lb_object_as_list = local.use_existing_lb ? [for lb in data.oci_load_balancer_load_balancers.existing_load_balancers_data_source.load_balancers[*] : lb if lb.id == var.existing_load_balancer_id] : []
    valid_existing_lb          = length(local.existing_lb_object_as_list) == 1
    use_existing_lb            = local.add_load_balancer && local.existent_load_balancer
    lb_backendset_name         = local.use_existing_lb ? var.backendset_name_for_existing_load_balancer : substr(format("%s-%v-lbset",local.wls_domain_name,local.state_id),0,32)

  # Filter configured nsgs eligible for resource creation
    pub_lb_nsg_config = try(var.nsgs.pub_lb, { create = "never" })
    pub_lb_nsg_create = coalesce(lookup(local.pub_lb_nsg_config, "create", null), "auto")
    pub_lb_nsg_enabled = anytrue([
      local.pub_lb_nsg_create == "always",
      alltrue([
        local.pub_lb_nsg_create == "auto", # true
        coalesce(lookup(local.pub_lb_nsg_config, "id", null), "none") == "none",  #true
        var.add_load_balancer, #true
      ]),
    ])
  # Filter configured loadbalancers eligible for resource creation
    pub_lb_config = try(var.lbs.pub_lb, { create = "never" })
    pub_lb_create = coalesce(lookup(local.pub_lb_config, "create", null), "auto")
    pub_lb_enabled = anytrue([
      local.pub_lb_create == "always",
      alltrue([
        local.pub_lb_create == "auto",
        coalesce(lookup(local.pub_lb_config, "id", null), "none") == "none",
        var.add_load_balancer,
      ]),
    ])
    # Return provided Public Ids when configured with an existing ID or created resource ID
    pub_lb_id = one(compact([lookup(var.lbs.pub_lb,"id", null), one(module.load-balancer[*].wls_loadbalancer_id)]))
}


module "load-balancer" {
  #depends_on = [module.network-validation]
  source = "./modules/lb/loadbalancer"
#  count  = (local.add_load_balancer && ! local.existent_load_balancer ) ? 1 : 0
  count  = local.pub_lb_enabled ? 1 :0

  compartment_id           = coalesce(var.network_compartment_id, local.compartment_id)
  lb_reserved_public_ip_id = compact([var.lb_reserved_public_ip_id])
  is_lb_private            = false #var.is_lb_private
  lb_nsg_id                = compact(flatten([try(length(trimspace(var.nsgs.pub_lb.id)) > 0 ? [var.nsgs.pub_lb.id] : [], []), try([module.network.pub_lb_nsg_id], [])]))
  lb_max_bandwidth         = var.lb_shape.pub_lb.max
  lb_min_bandwidth         = var.lb_shape.pub_lb.min
  lb_name                  = format("%s-%v-lb",local.wls_domain_name,local.state_id)
  lb_subnet_id             = compact(flatten([lookup(var.subnets.pub_lb,"id",null),try(module.network.pub_lb_subnet_id, null)])) #compact(flatten([lookup(var.subnets.pub_lb,"id",null), try(module.network.pub_lb_subnet_id, null)])) #[module.network.pub_lb_subnet_id]
  state_id            = local.state_id
  lb_shape = var.lb_shape.pub_lb.shape
  # Tagging
  tag_namespace    = var.tag_namespace
  use_defined_tags = var.use_defined_tags
  defined_tags  = local.service_lb_defined_tags
  freeform_tags = local.service_lb_freeform_tags
}

module "load-balancer-managed_server-backends" {
  #depends_on = [module.network-validation]
  depends_on = [module.wlsservers]
  source = "./modules/lb/backends"
  count  = local.add_load_balancer ? 1 : 0
  state_id            = local.state_id
  wls_load_balancer_id     = local.pub_lb_id #local.add_load_balancer ? (! local.existent_load_balancer ? var.existing_load_balancer_id : one(coalescelist(module.load-balancer[*].wls_loadbalancer_id, [""]))) : null
  use_existing_lb      = local.use_existing_lb
  lb_backendset_name   = local.lb_backendset_name
  health_check_url     = "/"
  resource_name_prefix = local.wls_domain_name
  number_backends =  length(one(module.wlsservers[*].wlsserver_private_ips ))
  backend_instances = one(module.wlsservers[*].wlsserver_private_ips )
  backend_ports = local.wls_all_ports_application_traffic_servers
  #If WLS Servers (static or dynamic) has multiple listen ports, setting LB backend port to 0 to force health check to validate each instance ip+port availability. Else defaults to Managed Server Static listen Port
  health_check_backend_port = try(one(local.wls_dynamic_server_app_traffic_port),0) != try(one(local.wls_managed_server_listen_ports),0) ? local.OCI_LB_HEALTH_CHECK_PORT_DEFAULT : try(one(local.wls_managed_server_listen_ports),local.OCI_LB_HEALTH_CHECK_PORT_DEFAULT)
}

#module "load-balancer-dynamic_servers-backends" {
#  #depends_on = [module.network-validation]
#  source = "./modules/lb/backends"
#  for_each= local.add_load_balancer ? tomap(local.wls_merged_templates_details ): {}
#
##  count  = local.add_load_balancer ? 1 : 0
#  state_id            = local.state_id
#  wls_load_balancer_id     = local.pub_lb_id #local.add_load_balancer ? (! local.existent_load_balancer ? var.existing_load_balancer_id : one(coalescelist(module.load-balancer[*].wls_loadbalancer_id, [""]))) : null
#  use_existing_lb      = local.use_existing_lb
#  lb_backendset_name   = format("%s-%v-dynamicserver",each.value.DynamicServers.ServerNamePrefix,local.state_id)
#  health_check_url     = "/"
#  resource_name_prefix = local.wls_domain_name
#  backend_instance_ports = local.lb_backends_to_map
#  #Health check can only use one port.Assuming all Dynamic Servers Templates are listening on the same listen port.
##  backend_port = try(one(local.wls_merged_templates_details).port, local.MS_LISTEN_PORT_NOT_SET)
#  backend_port =  each.value.ListenPort
#}
