# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

output "dynamic_group_ids" {
  description = "Cluster IAM dynamic group IDs"
  value = local.has_policy_statements ? compact([
    one(oci_identity_dynamic_group.wlsservers[*].id),
#    one(oci_identity_dynamic_group.operator[*].id),
  ]) : null
}

output "policy_statements" {
  description = "Cluster IAM policy statements"
  value       = local.has_policy_statements ? local.policy_statements : null
}
