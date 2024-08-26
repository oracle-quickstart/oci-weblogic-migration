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
  create_domain          = var.create_domain  #true

  # Network
  create_vcn     = false
  vcn_id         = var.vcn_id
  assign_dns     = var.assign_dns

  subnets = {
    wlsservers = { create = "never", id = var.wlsserver_subnet_id }
  }

  nsgs = {
    managedserver = { create = "never", id = var.managedserver_nsg_id }
    adminserver = { create = "never", id = var.adminserver_nsg_id }
  }

# Loadbalancer
  add_load_balancer=  var.add_load_balancer

# Weblogic Servers
  ssh_public_key   = local.ssh_public_key
  ssh_public_key_path = var.ssh_public_key_path
#wlsserver_pool_size = var.wlsserver_pool_size
#wlsserver_pool_mode = lookup({
#"Node Pool"       = "node-pool"
#"Instances"       = "instances"
#"Instance Pool"   = "instance-pool",
#"Cluster Network" = "cluster-network",
#}, var.wlsserver_pool_mode, "node-pool")

  wlsserver_pools=var.wlsserver_pools

  wlsserver_image_type       = lower(local.wlsserver_image_type)
  wlsserver_image_id         = local.wlsserver_image_id
  wlsserver_image_os         = var.wlsserver_image_os
  wlsserver_image_os_version = var.wlsserver_image_os_version
  wlsserver_cloud_init       = local.wlsserver_cloud_init

  wlsserver_shape = {
  shape            = var.wlsserver_shape
  ocpus            = var.wlsserver_ocpus
  memory           = var.wlsserver_memory
  boot_volume_size = var.wlsserver_boot_volume_size
  }

  #archive
  bucket_name = var.bucket_name
  restore_wls_archives = "all"
  await_node_readiness = "all"

#wlsserver_pools = {
#format("%v", var.wlsserver_pool_name) = {
#description = lookup({
#"Node Pool"       = "WLS-managed Node Pool"
#"Instances"       = "Self-managed Instances"
#"Instance Pool"   = "Self-managed Instance Pool"
#"Cluster Network" = "Self-managed Cluster Network"
#}, var.wlsserver_pool_mode, "")
#}
#}

  freeform_tags = {
    wlsservers = lookup(var.wlsserver_tags, "freeformTags", {})
  }

  defined_tags = {
    wlsservers = lookup(var.wlsserver_tags, "definedTags", {})
  }
}