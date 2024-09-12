output "joi_enabled_instances" {
  value = module.wlsservers[*].enabled_instances
}

output "joi_instances_changes" {
  value = module.wlsservers[*].wlsserver_instance_changes
}

output "joi_wlsserver_pools_with_defaults" {
  value = module.wlsservers[*].wlsserver_pools_with_defaults
}

output "joi_node_pool_images" {
  value = local.node_pool_images
}

output "joi_parsed_images" {
  value = local.parsed_images
}

output "joi_image_ids" {
  value = local.image_ids
}

output "joi_wlsserver_instances" {
  value = module.wlsservers[*].wlsserver_instances
}

output "joi_wlsserver_instance_ips" {
  value = module.wlsservers[*].wlsserver_pool_ips
}

output "joi_oci_volumes" {
  value = module.wlsservers[*].local_oci_volumes
}

output "joi_data_volume_ids" {
  value = module.wlsservers[*].oci_volumes
}

output "joi_adminserver_nsg_ids" {
  value = coalescelist([module.network.adminserver_nsg_id])
}

output "joi_managedserver_nsg_ids" {
  value = coalescelist([module.network.wlsserver_nsg_id])
}

output "joi_pub_lb_config" {
  value = local.pub_lb_config
}

output "joi_pub_lb_create" {
  value = local.pub_lb_create
}

output "joi_pub_lb_enabled" {
 value= local.pub_lb_enabled
}

output "joi_instance_private_ips" {
  value = local.instance_private_ips
}

output "joi_wls_managed_server_listen_ports" {
  value = local.wls_managed_server_listen_ports
}

output "joi_wls_merged_templates_details" {
  value = local.__wls_merged_templates_details
}

output "joi_host_details" {
  value = local.__host_details
}

output "joi_wlsserver_pool_size" {
  value = one(module.wlsservers).wlsserver_pool_size
}

output "joi_wls_instance_params" {
  value = local.wls_instance_params
}

output "joi_machine_placement" {
  value = local.__machine_placement
}


output "joi_wls_dynamic_server_app_traffic_port" {
  value = local.wls_dynamic_server_app_traffic_port
}

output "joi_wls_all_ports_application_traffic_servers" {
  value = local.wls_all_ports_application_traffic_servers
}
#output "joi__manual_backend_ips" {
#  value = local.__manual_backend_ips
#}

output "joi___wls_dyn_app_ports_tempo" {
  value = local.__wls_dyn_app_ports_tempo
}

output "joi_oci_instance_ips" {
  value = local.oci_instance_ips
}

# Bastion
output "joi_bastion_image_ids" {
  value = local.bastion_image_ids
}
