# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
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


  #TODO: JOI Future version narrow access to specific bucket  target.bucket.name
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
  network_compartment_policy_templates = tolist([
    format("Allow dynamic-group ${local.wlsserver_group_name} to inspect virtual-network-family in compartment id %v", var.network_compartment_id)
  ])

  # This policy with "use autonomous-transaction-processing-family" verb is needed to download ATP db wallet.
   atp_db_policy_template_1 = compact(concat(
       (var.db_strategy_is_atp || var.db_strategy_is_edit_string_atp) ? [
         format(
           "Allow dynamic-group ${local.wlsserver_group_name} to use autonomous-transaction-processing-family in compartment id %s",
           var.atp_db_compartment_id_0
         )
       ] : []
   ))
  # This policy is used to add the db port 1522 in case of ATP db
  # The functionality is yet to be added till (Jun 25)
   atp_db_policy_template_2 = compact(concat(
     (var.db_strategy_is_atp || var.db_strategy_is_edit_string_atp || (var.atp_db_existing_vcn_id_0 != "" && var.atp_has_private_endpoints_0)) ? [
       format(
         "Allow dynamic-group ${local.wlsserver_group_name} to manage network-security-groups in compartment id %s where request.operation = 'AddNetworkSecurityGroupSecurityRules'",
          var.atp_db_network_compartment_id_0
       )
     ] : []
   ))


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
    local.network_compartment_policy_templates,
    local.atp_db_policy_template_1,
    local.atp_db_policy_template_2
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