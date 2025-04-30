# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

#TODO: JOI Review operator and cluster policy. Needed?
locals {
  policy_statements = distinct(compact(flatten([
    local.wlsserver_policy_statements,
    #    local.operator_policy_statements,
  ])))

  has_policy_statements = var.create_iam_resources && anytrue([
    var.create_iam_kms_policy,
    var.create_iam_wlsserver_policy,
  ])
}

resource "oci_identity_policy" "wlsdomain" {
  provider       = oci.home
  count          = local.has_policy_statements ? 1 : 0
  compartment_id = var.tenancy_id
  description    = format("Policies for WLS Domain %s Terraform state %v", var.resource_name_prefix, var.state_id)
  name           = local.wlsdomain_group_name
  statements     = local.policy_statements
  defined_tags   = local.defined_tags
  freeform_tags  = local.freeform_tags
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}
