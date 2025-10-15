# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

data "oci_identity_tag_namespaces" "wls" {
  count          = var.create_iam_resources ? 1 : 0
  provider       = oci.home
  compartment_id = var.compartment_id
  filter {
    name   = "name"
    values = [var.tag_namespace]
  }

  state = "ACTIVE" // TODO Support reactivation of retired namespace w/ update
}

data "oci_identity_tags" "wls" {
  count            = var.create_iam_resources && local.tag_namespace_id_found != null ? 1 : 0
  provider         = oci.home
  tag_namespace_id = local.tag_namespace_id_found
  state            = "ACTIVE" // TODO Support reactivation of retired tag w/ update
}

locals {
  # Filtered value from data source (only 1 by name, or null)
  # Identified tag namespace ID when not created and used
  tag_namespace_id_found = try(
    data.oci_identity_tag_namespaces.wls[0].tag_namespaces[0].id,
    null
  )

  create_iam_tag_namespace = alltrue([
    var.create_iam_resources,
    var.create_iam_tag_namespace,
    local.tag_namespace_id_found == null,
    one(data.oci_identity_tags.wls[*].tags) == null,
  ])

  # Map of standard tags & descriptions to be created if enabled
  tags = var.create_iam_resources && var.create_iam_defined_tags ? {
    "role"               = "Functional role of a resource"
    "state_id"           = "Terraform state ID associated with a resource"
  } : {}

  # Standard tags as freeform if defined tags are disabled
  freeform_tags = merge(var.freeform_tags, !var.use_defined_tags ? {
    "state_id" = var.state_id,
    "role"     = "iam",
    } : {},
  )

  # Standard tags as defined if enabled for use
  defined_tags = merge(var.defined_tags, var.use_defined_tags ? {
    "${var.tag_namespace}.state_id" = var.state_id,
    "${var.tag_namespace}.role"     = "iam",
    } : {},
  )
}

resource "oci_identity_tag_namespace" "wls" {
  provider       = oci.home
  count          = local.create_iam_tag_namespace ? 1 : 0
  compartment_id = var.compartment_id
  description    = "Tag namespace for WLS resources"
  name           = var.tag_namespace
  defined_tags   = local.defined_tags
  freeform_tags  = local.freeform_tags
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}

resource "oci_identity_tag" "wls" {
  provider         = oci.home
  for_each         = local.create_iam_tag_namespace ? local.tags : {} #{ for k, v in oci_identity_tag_namespace.wls : k => local.tags } # local.create_iam_tag_namespace ? local.tags : {}
  description      = each.value
  name             = each.key
  defined_tags     = local.defined_tags
  freeform_tags    = local.freeform_tags
  tag_namespace_id = one(oci_identity_tag_namespace.wls[*].id)

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}
