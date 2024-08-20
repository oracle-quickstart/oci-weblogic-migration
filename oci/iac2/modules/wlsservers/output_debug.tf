##Debug Output
output "wlsserver_pools_with_defaults" {
  value = local.wlsserver_pools_with_defaults
}

output "enabled_wlsserver_pools" {
  value = local.enabled_wlsserver_pools
}

output "local_oci_volumes" {
  value = local.oci_volumes
}

output "oci_volumes" {
  value = local.oci_volumes
#  value = module.wls-volumes.data_volume_ids
}
