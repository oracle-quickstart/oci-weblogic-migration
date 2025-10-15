# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "time_sleep" "await_iam_resources" {
  count = anytrue([
    local.has_policy_statements,
    local.create_iam_tag_namespace,
  ]) ? 1 : 0
  create_duration  = "30s"
  destroy_duration = "0s"
}
