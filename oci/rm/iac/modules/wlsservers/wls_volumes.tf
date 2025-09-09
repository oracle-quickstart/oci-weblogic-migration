
locals {
  oci_volumes = flatten([
  for k, v in local.wlsserver_instances : [
    for i,device in local.block_storage_devices_defaults : {
      ad = oci_core_instance.wlsservers[k].availability_domain
      device_key   = format("%s-%v-%s", k, var.state_id, device.name)
      instance_key = oci_core_instance.wlsservers[k].id
      oci_device   = device
      attachment_type = var.block_volume_type
      index = i
      # Standard tags as defined if enabled for use
      # User-provided freeform tags are merged and take precedence
      defined_tags = merge(
        var.use_defined_tags ? merge(
          {
            "${var.tag_namespace}.state_id"           = var.state_id,
            "${var.tag_namespace}.role"               = "blockvolume",
            "${var.tag_namespace}.domain"               = var.resource_name_prefix,
            #            "${var.tag_namespace}.pool"               = pool_name,
            #TODO:  JOI - add type = managedserver or adminserver
            #"${var.tag_namespace}.type"               = if (adminserver) ? adminserver: managedserver,

          },
        ) : {},
        var.storage_defined_tags
      )

      # Standard tags as freeform if defined tags are disabled
      # User-provided freeform tags are merged and take precedence
      freeform_tags = merge(
        var.use_defined_tags ? {} : merge(
          {
            "state_id"           = var.state_id,
            "role"               = "blockvolume",
            "domain"               = var.resource_name_prefix,
            #TODO:  JOI - add type = managedserver or adminserver
            #"type"               = if (adminserver) ? adminserver: managedserver,
          }
        ),
        var.storage_freeform_tags
      )
      }
  ]
  ])
}

#module "wls-volumes" {
#  source = "../volume"
#  compartment_id = var.compartment_id
#  oci_volumes = local.oci_volumes
#}