#Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
wlsserver_image_id   = coalesce(var.wlsserver_image_custom_id, var.wlsserver_image_platform_id, "none")
wlsserver_image_type = contains(["platform", "custom"], lower(var.wlsserver_image_type)) ? "custom" : "wls"

wlsserver_cloud_init = var.wlsserver_cloud_init_configure ? [{
content_type = "text/x-shellscript",
content      = var.wlsserver_pool_mode == "Node Pool" ? var.wlsserver_cloud_init_wls : var.wlsserver_cloud_init_byon
}] : []
}

module "wls" {
#source    = "github.com/oracle-terraform-modules/terraform-oci-wls.git?ref=5.x&depth=1"
source = "../../../"
providers = { oci.home = oci.home }

# Identity
tenancy_id     = var.tenancy_ocid
compartment_id = var.compartment_ocid

create_iam_resources         = true
#create_iam_autoscaler_policy = var.create_iam_autoscaler_policy ? "always" : "never"  #never - future service
create_iam_autoscaler_policy = "never"
create_iam_wlsserver_policy     = var.create_iam_wlsserver_policy ? "always" : "never"
create_bastion               = false
create_operator              = false  #false - future service
create_cluster               = false  #false - future service

# Network
create_vcn     = false
vcn_id         = var.vcn_id
assign_dns     = var.assign_dns
wlsserver_nsg_ids = compact([var.wlsserver_nsg_id])
pod_nsg_ids    = compact([var.pod_nsg_id])

subnets = {
wlsservers = { create = "never", id = var.wlsserver_subnet_id }
pods    = { create = "never", id = var.pod_subnet_id }
}

nsgs = {
wlsservers = { create = "never", id = var.wlsserver_nsg_id }
adminserver    = { create = "never", id = var.pod_nsg_id }
}

# Cluster
cluster_id              = var.cluster_id
cni_type                = lower(var.cni_type)
control_plane_is_public = false # wlsservers only need private

# wlsservers
ssh_public_key   = local.ssh_public_key
wlsserver_pool_size = var.wlsserver_pool_size
wlsserver_pool_mode = lookup({
"Node Pool"       = "node-pool"
"Instances"       = "instances"
"Instance Pool"   = "instance-pool",
"Cluster Network" = "cluster-network",
}, var.wlsserver_pool_mode, "node-pool")

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

wlsserver_pools = {
format("%v", var.wlsserver_pool_name) = {
description = lookup({
"Node Pool"       = "WLS-managed Node Pool"
"Instances"       = "Self-managed Instances"
"Instance Pool"   = "Self-managed Instance Pool"
"Cluster Network" = "Self-managed Cluster Network"
}, var.wlsserver_pool_mode, "")
}
}

freeform_tags = {
wlsservers = lookup(var.wlsserver_tags, "freeformTags", {})
}

defined_tags = {
wlsservers = lookup(var.wlsserver_tags, "definedTags", {})
}
}