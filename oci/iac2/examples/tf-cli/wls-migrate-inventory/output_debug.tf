#output "joi_parsed_images" {
#  value = module.wls.joi_parsed_images
#}
#
#output "joi_image_ids" {
#  value = module.wls.joi_image_ids
#}
#
#
##output "joi_wlsserver_instances" {
##  value = module.wls.joi_wlsserver_instances
##}
#
#output "joi_enabled_instances" {
#  value = module.wls.joi_enabled_instances
#}

##output "joi_data_volume_ids" {
##  value = module.wls.joi_node_pool_images
##}
#
#output "joi_node_pool_images" {
#  value = module.wls.joi_node_pool_images
#}

#output "joi_wls_merged_templates_details" {
#  value = module.wls.joi_wls_merged_templates_details
#}

output "joi_wls_managed_server_listen_ports" {
  value = module.wls.joi_wls_managed_server_listen_ports
}

#output "joi_host_details" {
#  value = module.wls.joi_host_details
#}

#output "joi_wlsserver_pool_size" {
#  value = module.wls.joi_wlsserver_pool_size
#}

#output "joi_wls_instance_params" {
#  value = module.wls.joi_wls_instance_params
#}

#output "joi_machine_placement" {
#  value = module.wls.joi_machine_placement
#}

#output "joi__wls_dynamic_server_dynamic_ports_by_instance" {
#  value = module.wls.joi__wls_dynamic_server_dynamic_ports_by_instance
#}
#
#output "joi_wls_dynamic_server_app_traffic_port" {
#  value = module.wls.joi_wls_dynamic_server_app_traffic_port
#}

#output "joi_wlsserver_instance_ips" {
#  value = module.wls.joi_wlsserver_instance_ips
#}
#
#output "joi_instance_private_ips" {
#  value = module.wls.joi_instance_private_ips
#}

#output "joi_instances_changes" {
#  value = module.wls.joi_instances_changes
#}

#output "joi__manual_backend_ips" {
#  value = module.wls.joi__manual_backend_ips
#}

output "joi___wls_dyn_app_ports_tempo" {
  value = module.wls.joi___wls_dyn_app_ports_tempo
}
#
#output "joi_oci_instance_ips" {
#  value = module.wls.joi_oci_instance_ips
#}

output "joi_wls_all_ports_application_traffic_servers" {
  value = module.wls.joi_wls_all_ports_application_traffic_servers
}

# Bastion
output "joi_bastion_image_ids" {
  value = module.wls.joi_bastion_image_ids
}