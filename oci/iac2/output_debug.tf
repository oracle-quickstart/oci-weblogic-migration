output "joi_enabled_instances" {
  value = module.wlsservers[*].enabled_wlsserver_pools
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

output "joi_oci_volumes" {
  value = module.wlsservers[*].local_oci_volumes
}

output "joi_data_volume_ids" {
  value = module.wlsservers[*].oci_volumes
}

