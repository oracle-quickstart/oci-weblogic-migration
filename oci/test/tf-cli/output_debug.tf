output "joi_enabled_instances" {
  value = null #module.wls.joi_enabled_instances
}

#output "joi_parsed_images" {
#  value = module.wls.joi_parsed_images
#}
#
#output "joi_image_ids" {
#  value = module.wls.joi_image_ids
#}
#
#
#output "joi_wlsserver_instances" {
#  value = module.wls.joi_wlsserver_instances
#}
#

#
#
#
##output "joi_data_volume_ids" {
##  value = module.wls.joi_node_pool_images
##}
#
#output "joi_node_pool_images" {
#  value = module.wls.joi_node_pool_images
#}

#output "joi_wls_dynamic_server_dynamic_ports_by_instance" {
#  value = module.wls.joi_wls_dynamic_server_dynamic_ports_by_instance
#}

output "joi_image_id" {
  value = coalesce(module.wls.joi_module_image_id,"nulllito")
}

output "vm_instance_image_id" {
  value = coalesce(local.vm_instance_image_id,"somethingoff")
}

output "vm_image_type_selected" {
  value = local.image_type_selected_key
}

output "vm_image_type" {
  value = local.wlsserver_image_type
}

output "platform_image" {
  value = coalesce(var.wlsserver_image_platform_id,"butwhy?")
}

output "ssh_to_nodes" {
  value = module.wls.ssh_to_nodes
}

output "joi_allow_adminserver_ssh_access" {
  value = module.wls.joi_allow_adminserver_ssh_access
}

output "joi_allow_weblogic_ssh_access" {
  value = module.wls.joi_allow_weblogic_ssh_access
}