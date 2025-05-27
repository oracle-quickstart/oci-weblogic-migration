# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

data "oci_identity_availability_domains" "all" {
  compartment_id = local.compartment_id
}

locals {
  // Tenancy-specific availability domains in region
  // Common reference for data source re-used throughout module
  ads = data.oci_identity_availability_domains.all.availability_domains

  // Map of parsed availability domain numbers to tenancy-specific names
  // Used by resources with AD placement for generic selection
  ad_numbers_to_names = local.ads != null ? {
  for ad in local.ads : parseint(substr(ad.name, -1, -1), 10) => ad.name
  } : { -1 : "" } # Fallback handles failure when unavailable but not required

  // List of availability domain numbers in region
  // Used to intersect desired AD lists against presence in region
  ad_numbers = local.ads != null ? sort(keys(local.ad_numbers_to_names)) : []

  create_iam_wlsserver_policy = anytrue([
    var.create_iam_wlsserver_policy == "always",
    var.create_iam_wlsserver_policy == "auto"
  ])

  create_iam_autoscaler_policy = anytrue([
    var.create_iam_autoscaler_policy == "always",
    var.create_iam_autoscaler_policy == "auto"
  ])

  create_iam_operator_policy = anytrue([
    var.create_iam_operator_policy == "always",
    var.create_iam_operator_policy == "auto" #&& local.operator_enabled
  ])

  create_iam_kms_policy = anytrue([
    var.create_iam_kms_policy == "always",
    var.create_iam_kms_policy == "auto" && anytrue([
      coalesce(var.wlsserver_volume_kms_key_id, "none") != "none",
#      coalesce(var.cluster_kms_key_id, "none") != "none",
    ])
  ])
}

# Default IAM sub-module implementation for Weblogic Domain
module "iam" {
  source                       = "./modules/iam"
  compartment_id               = local.compartment_id
  state_id                     = local.state_id
  tenancy_id                   = local.tenancy_id
  create_iam_resources         = var.create_iam_resources
  create_iam_autoscaler_policy = local.create_iam_autoscaler_policy
  create_iam_kms_policy        = local.create_iam_kms_policy
  create_iam_wlsserver_policy     = local.create_iam_wlsserver_policy

  create_iam_tag_namespace = var.create_iam_tag_namespace
  create_iam_defined_tags  = var.create_iam_defined_tags
  defined_tags             = local.iam_defined_tags
  freeform_tags            = local.iam_freeform_tags
  tag_namespace            = var.tag_namespace
  use_defined_tags         = var.use_defined_tags

  add_load_balancer = var.add_load_balancer
  db_strategy_is_atp     = var.db_strategy_is_atp

  wlsserver_volume_kms_key_id   = var.wlsserver_volume_kms_key_id

  wlsserver_compartments     = local.wlsserver_compartments

  providers = {
    oci.home = oci.home
  }
  #TODO: JOI: Future release include multiple object storage compartment
  object_storage_compartments = []
  resource_name_prefix = local.wls_domain_name
}

output "availability_domains" {
  description = "Availability domains for tenancy & region"
  value       = local.ad_numbers_to_names
}

output "dynamic_group_ids" {
  description = "Cluster IAM dynamic group IDs"
  value       = module.iam.dynamic_group_ids
}

output "policy_statements" {
  description = "Cluster IAM policy statements"
  value       = module.iam.policy_statements
}

