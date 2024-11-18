##Debug Output
output "wlsserver_pools_with_defaults" {
  value = local.wlsserver_pools_with_defaults
}

output "enabled_wlsserver_pools" {
  value = local.enabled_wlsserver_pools
}

output "enabled_instances" {
  value = local.enabled_instances
}

output "local_oci_volumes" {
  value = local.oci_volumes
}

output "oci_volumes" {
  value = local.oci_volumes
#  value = module.wls-volumes.data_volume_ids
}


output "wlsserver_instance_changes" {
  description = "Create wlsserver instances merged with original discovered properties to track changes"
  value = local.wlsserver_instance_changes
}


output "wlsserver_pool_size" {
  value = var.wlsserver_pool_size
}

output "image_id" {
  value = var.image_id
}