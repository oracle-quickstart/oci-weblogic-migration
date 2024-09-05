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

output "joi_lb_backends_to_map" {
  value = local.lb_backends_to_map
}

output "joi_instance_private_ips" {
  value = local.instance_private_ips
}