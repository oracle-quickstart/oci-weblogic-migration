# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Common
variable "compartment_id" { type = string }
variable "state_id" { type = string }
variable "tenancy_id" { type = string }
variable "wlsserver_compartments" { type = list(string) }
variable "resource_name_prefix" {
  type        = string
  description = "Prefix used by the WebLogic for OCI instance of which this compute is part"
}

# Tags
variable "create_iam_defined_tags" { type = bool }
variable "create_iam_tag_namespace" { type = bool }
variable "defined_tags" { type = map(string) }
variable "freeform_tags" { type = map(string) }
variable "tag_namespace" { type = string }
variable "use_defined_tags" { type = bool }

# Policy
variable "object_storage_compartments" { type = list(string) }
variable "create_iam_resources" { type = bool }
variable "create_iam_autoscaler_policy" { type = bool }
variable "create_iam_kms_policy" { type = bool }
variable "create_iam_wlsserver_policy" { type = bool }

# KMS

variable "wlsserver_volume_kms_key_id" { type = string }

#load_balancer
variable "add_load_balancer" {
  type    = bool
  default = false
}

#ATPDB
variable "db_strategy_is_atp" {
  type = string
}
variable "db_strategy_is_edit_string_atp" {
  type = string
}


