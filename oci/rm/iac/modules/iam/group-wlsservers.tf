# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  wlsdomain_group_name          = format("wls-%s-%v", var.resource_name_prefix, var.state_id)
  wlsserver_group_name          = format("wls-wlsservers-%v", var.state_id)
  wlsserver_compartments        = coalescelist(var.wlsserver_compartments, [var.compartment_id])
  wlsserver_compartment_matches = formatlist("instance.compartment.id = '%v'", local.wlsserver_compartments)
  wlsserver_compartment_rule    = format("ANY {%v}", join(", ", local.wlsserver_compartment_matches))
  bucket_compartment            = var.bucket_compartment
  network_compartment_id        = var.network_compartment_id

  wlsserver_group_rules = var.use_defined_tags ? format("ALL {%v}", join(", ", [
    format("tag.%v.role.value='wlsserver'", var.tag_namespace),
    format("tag.%v.state_id.value='%v'", var.tag_namespace, var.state_id),
    format("tag.%v.domain.value='%v'", var.tag_namespace, var.resource_name_prefix),
  ])) : local.wlsserver_compartment_rule


  #TODO: JOI Future version narrow access to specific bucket target.bucket.name
  wlsservers_object_storage_templates = tolist([
    "Allow dynamic-group ${local.wlsserver_group_name} to read buckets in compartment id %v",
    "Allow dynamic-group ${local.wlsserver_group_name} to read objects in compartment id %v"
  ])

  # TODO support keys defined at wlsserver group level
  wlsserver_kms_volume_templates = tolist([
    #    "Allow service wls to USE key-delegates in compartment id %v where target.key.id = '%v'",
    "Allow service blockstorage to USE keys in compartment id %v where target.key.id = '%v'",
    "Allow dynamic-group ${local.wlsserver_group_name} to USE key-delegates in compartment id %v where target.key.id = '%v'",
  ])

  #policies for migration
  #compartment level
  migration_compartment_policy_templates = tolist([
    "Allow dynamic-group ${local.wlsserver_group_name} to use instance-family in compartment id %v",
    "Allow dynamic-group ${local.wlsserver_group_name} to manage volume-family in compartment id %v",
    "Allow dynamic-group ${local.wlsserver_group_name} to manage tag-namespaces in compartment id %v",
    "Allow dynamic-group ${local.wlsserver_group_name} to use app-catalog-listing in compartment id %v",
  ])

  # This policy with "inspect virtual-network-family" verb is needed to read VCN information like CIDR, etc.
  network_compartment_policy_statements = [
    format("Allow dynamic-group ${local.wlsserver_group_name} to inspect virtual-network-family in compartment id %v", var.network_compartment_id)
  ]

  # === IAM policy for multi data sources ===

  # Common: Security List or Subnet policies — required when either
  # - `existing_vcn_add_seclist` is true (for ATP or OCI DB with private endpoint), or
  # - `is_vcn_peering` is true (VCN peering required for DB access)
  # This policy with "manage virtual-network-family" verb enables required access for both cases.
  mds_network_access_compartment_ids = distinct([
    for config_key, jdbc_string in var.wls_datasources_config :
    jdbc_string.db_network_compartment_id
    if (
    (try(jdbc_string.existing_vcn_add_seclist, false) || try(jdbc_string.is_vcn_peering, false))
    && try(trimspace(jdbc_string.db_network_compartment_id), "") != ""
    )
  ])
  mds_network_access_policy_statements = flatten([
    for comp_id in local.mds_network_access_compartment_ids : [
      "Allow dynamic-group ${local.wlsserver_group_name} to manage virtual-network-family in compartment id ${comp_id}"
    ]
  ])


  # This policy with "use autonomous-transaction-processing-family" verb is needed to download ATP db wallet.
  mds_atp_wallet_compartment_ids = can(var.wls_datasources_config) ? distinct([
    for config_key, jdbc_string in var.wls_datasources_config :
    jdbc_string.atp_db.compartment_id
    if (
    try(jdbc_string.is_atp, false)
    && try(trimspace(jdbc_string.atp_db.compartment_id), "") != ""
    ) || (
    can(regex("adb", try(jdbc_string.connection_string, "")))
    )
  ]) : []
  mds_atp_wallet_policy_statements = flatten([
    for comp_id in local.mds_atp_wallet_compartment_ids : [
      "Allow dynamic-group ${local.wlsserver_group_name} to use autonomous-transaction-processing-family in compartment id ${comp_id}"
    ]
  ])

  # Block volume encryption using OCI Key Management System (KMS)
  wlsserver_kms_volume_statements = coalesce(var.wlsserver_volume_kms_key_id, "none") != "none" ? flatten(tolist([
    for statement in local.wlsserver_kms_volume_templates :
    formatlist(statement, local.wlsserver_compartments, var.wlsserver_volume_kms_key_id)
  ])) : []

  # Object Storage access  (OSS)
  wlsservers_object_storage_statements = flatten(tolist([
    for statement in local.wlsservers_object_storage_templates :
    formatlist(statement, local.bucket_compartment)
  ]))

  migration_compartment_policy_statements = var.create_iam_wlsserver_policy ? flatten(tolist([
    for statement in local.migration_compartment_policy_templates :
    formatlist(statement, local.wlsserver_compartments)
  ])) : []

  # Use the templates only if the flag is enabled


  wlsserver_policy_statements = var.create_iam_wlsserver_policy ? tolist(concat(
    local.wlsservers_object_storage_statements,
    local.wlsserver_kms_volume_statements,
    local.migration_compartment_policy_statements,
    local.network_compartment_policy_statements,
    local.mds_network_access_policy_statements,
    local.mds_atp_wallet_policy_statements
  )) : []
}

resource "oci_identity_dynamic_group" "wlsservers" {
  provider       = oci.home
  count          = var.create_iam_resources && var.create_iam_wlsserver_policy ? 1 : 0
  compartment_id = var.tenancy_id # dynamic groups exist in root compartment (tenancy)
  description    = format("Dynamic group of Weblogic Server nodes for WLS Terraform state %v", var.state_id)
  matching_rule  = local.wlsserver_group_rules
  name           = local.wlsserver_group_name
  defined_tags   = local.defined_tags
  freeform_tags  = local.freeform_tags
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}