#Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
wlsserver_image_id   = coalesce(var.wlsserver_image_custom_id, var.wlsserver_image_platform_id, "none")
wlsserver_image_type_map = {
    "custom": "custom",
    "Oracle WebLogic Server BYOL": "platform"
    "Oracle Weblogic Suite UCM" : "suite-ucm"
    "Oracle WebLogic Server Enterprise Edition UCM": "ee-ucm"
}
#wlsserver_image_type = contains(["custom"], lower(var.wlsserver_image_type)) ? "custom" : contains(["Oracle WebLogic Server BYOL"], lower(var.wlsserver_image_type)) ? "ucm-ee":"ucm-suite"
  wlsserver_image_type = lookup(local.wlsserver_image_type_map,var.wlsserver_image_type,null)

  wlsserver_cloud_init = var.wlsserver_cloud_init_configure ? [{
content_type = "text/x-shellscript",
content      = var.wlsserver_cloud_init_byon
}] : []
}



module "wls" {
  #source    = "github.com/oracle-terraform-modules/terraform-oci-wls.git?ref=5.x&depth=1"
  source ="../../../../iac2"
  providers = { oci.home = oci.home }

  # Identity
  tenancy_id     = var.tenancy_ocid
  compartment_id = var.compartment_ocid

  create_iam_resources         = true
  create_iam_autoscaler_policy = "never"
  create_iam_wlsserver_policy     = var.create_iam_wlsserver_policy ? "always" : "never"
  create_bastion               = false
  #create_operator              = false
  create_domain          = false #var.create_domain  #true

  # Network
  create_vcn     = false
  vcn_id         = var.vcn_id
  assign_dns     = var.assign_dns

  subnets = {
    pub_lb = { create  = "never", id = var.pub_lb_subnet_id }
  }

  nsgs = {
    pub_lb   = { create = "never" , id = var.pub_lb_nsg_id}
  }





# Loadbalancer
  add_load_balancer=  var.add_load_balancer
  lbs = {
    pub_lb = { create = var.add_load_balancer ? "always" : "never", id = var.existing_load_balancer_id , backends=var.custom_backends}
  }
  lb_shape = {
    pub_lb = { shape=var.load_balancer_shape, min = var.lb_min_bandwidth, max=var.lb_max_bandwidth}

  }

# Weblogic Servers
  ssh_public_key   = local.ssh_public_key
  ssh_public_key_path = var.ssh_public_key_path

  wlsserver_pools=var.wlsserver_pools

  wlsserver_shape = {}

  #archive
  bucket_name = var.bucket_name
  restore_wls_archives = "none"
  await_node_readiness = "none"


  freeform_tags = {
    wlsservers = lookup(var.wlsserver_tags, "freeformTags", {})
  }

  defined_tags = {
    wlsservers = lookup(var.wlsserver_tags, "definedTags", {})
  }
}