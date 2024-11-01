#output "joi_enabled_instances" {
#  value = module.wls.joi_enabled_instances
#}

#output "joi_parsed_images" {
#  value = module.wls.joi_parsed_images
#}
#
#output "joi_image_ids" {
#  value = module.wls.joi_image_ids
#}


#output "joi_wlsserver_instances" {
#  value = module.wls.joi_wlsserver_instances
#}

#output "joi_enabled_instances" {
#  value = module.wls.joi_enabled_instances
#}



#output "joi_data_volume_ids" {
#  value = module.wls.joi_node_pool_images
#}

#output "joi_node_pool_images" {
#  value = module.wls.joi_node_pool_images
#}


#output "joi_pub_lb_config" {
#  value = module.wls.joi_pub_lb_config
#}
#
#output "joi_pub_lb_create" {
#  value = module.wls.joi_pub_lb_create
#}
#
#output "joi_pub_lb_enabled" {
#  value = module.wls.joi_pub_lb_enabled
#}

output "joi_lb_backend_to_map" {
  value = module.wls.joi_lb_backends_to_map
}