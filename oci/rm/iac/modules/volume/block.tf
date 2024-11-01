# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

resource "oci_core_volume" "wls" {
  for_each = {
      for elem in var.oci_volumes : elem.device_key => elem
  }
  availability_domain = each.value.ad
  compartment_id      = var.compartment_id
  display_name        = each.value.oci_device.name
  size_in_gbs         = each.value.oci_device.size
  defined_tags        = each.value.defined_tags
  freeform_tags       = each.value.freeform_tags
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags, display_name]
  }

}

resource "oci_core_volume_attachment" "wls" {
  for_each = {
      for elem in var.oci_volumes : elem.device_key => elem
  }
  display_name    = each.value.oci_device.name
  attachment_type = each.value.attachment_type
  instance_id     = each.value.instance_key
  volume_id       = oci_core_volume.wls[each.key].id
  lifecycle {
    ignore_changes = [display_name]
#    precondition {
#      condition     = coalesce(each.value.image_id, "none") != "none"
#      error_message = <<-EOT
#      Missing image_id; check provided value if image_type is 'custom', or image_os/image_os_version if image_type is 'marketplace' or 'platform'.
#        pool: ${each.key}
#        image_type: ${coalesce(each.value.image_type, "none")}
#        image_id: ${coalesce(each.value.image_id, "none")}
#      EOT
#    }
  }
}

