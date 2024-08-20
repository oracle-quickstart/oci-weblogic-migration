## Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
## Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
##
#
#resource "oci_core_instance" "mp_instance" {
#  availability_domain = random_shuffle.compute_ad.result[count.index % length(random_shuffle.compute_ad.result)]
#  compartment_id      = var.compartment_ocid
#  display_name        = "CPE Instance - ${var.cpe_vendor} (${random_string.deploy_id.result}) [${count.index}]"
#  shape               = var.mp_instance_shape.instanceShape
#  # is_pv_encryption_in_transit_enabled = var.is_pv_encryption_in_transit_enabled
#  freeform_tags = local.oci_tag_values.freeformTags
#  defined_tags  = local.oci_tag_values.definedTags
#
#  dynamic "shape_config" {
#    for_each = local.is_flexible_mp_instance_shape ? [1] : []
#    content {
#      ocpus         = var.mp_instance_shape.ocpus
#      memory_in_gbs = var.mp_instance_shape.memory
#    }
#  }
#
#  source_details {
#    source_type = "image"
##    source_id   = lookup(data.oci_core_images.cpe_compute_images.images[0], "id")
#    source_id = local.compute_image_id
#    # kms_key_id  = var.use_encryption_from_oci_vault ? (var.create_new_encryption_key ? oci_kms_key.cpe_key[0].id : var.encryption_key_id) : null
#  }
#
#  create_vnic_details {
#    subnet_id        = var.create_subnets ? module.subnets["test_subnet"].subnet_id : var.existent_test_subnet_ocid
#    display_name     = "primaryvnic"
#    assign_public_ip = (var.cpe_visibility == "Private") ? false : true
#    hostname_label   = "cpe-${random_string.deploy_id.result}-${count.index}"
#    skip_source_dest_check = true
#  }
#
#  metadata = {
#    ssh_authorized_keys = local.ssh_authorized_key
#    user_data           = data.cloudinit_config.cpe.rendered
#  }
#
#  count = 1
#}
#
#locals {
#  # Checks if is using Flexible Compute Shapes
#  is_flexible_mp_instance_shape = contains(split(".", var.mp_instance_shape.instanceShape), "Flex")
#}
#
## Compartment for CPE
#resource "oci_identity_compartment" "cpe_compartment" {
#  compartment_id = var.compartment_ocid
#  name           = "${local.app_name_normalized}-${local.deploy_id}"
#  description    = "${local.app_name} ${var.cpe_compartment_description} (Deployment ${local.deploy_id})"
#  enable_delete  = true
#
#  count = var.create_new_compartment_for_cpe ? 1 : 0
#}
#locals {
#  cpe_compartment_id = var.create_new_compartment_for_cpe ? oci_identity_compartment.cpe_compartment.0.id : var.compartment_ocid
#}
#
## Cloud Init
### CPE
#data "cloudinit_config" "cpe" {
#  gzip          = true
#  base64_encode = true
#
#  part {
#    filename     = "cloud-config.yaml"
#    content_type = "text/cloud-config"
#    content      = local.cloud_init_cpe
#  }
#}
#
### Files and Templatefiles
#locals {
##  cloud_init_cpe = templatefile("${path.module}/cloudinit/cloud_config_cpe.template.yaml",
##    {
##      shared_secret_psk = local.shared_secret_psk
##    })
#  cloud_init_cpe = ""
##  cloud_init_ldap_server = templatefile("${path.module}/cloudinit/cloud_config_ldap.template.yaml",
##    {
##      LDAP_ADMIN_PASSWORD = random_password.ldap_admin_password.result
##      LDAP_DOMAIN        = var.ldap_domain
##      LDAP_ORGANIZATION  = var.ldap_organization
##      LDAP_BACKEND       = "mdb"
##    })
#  cloud_init_ldap_server=""
#}
#
#resource "random_password" "ldap_admin_password" {
#  length           = 10
#}