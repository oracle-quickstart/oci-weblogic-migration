# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Common
variable "region" { type = string }
variable "wlsserver_pools" { type = any }

# Connection
variable "bastion_host" { type = string }
variable "bastion_user" { type = string }

variable "ssh_private_key" {
  type      = string
  sensitive = true
}

#TODO: JOI: retire operator
#variable "operator_host" { type = string }
#variable "operator_user" { type = string }

## OCIR
#variable "ocir_email_address" { type = string }
#variable "ocir_secret_id" { type = string }
#variable "ocir_secret_name" { type = string }
#variable "ocir_secret_namespace" { type = string }
#variable "ocir_username" { type = string }

# Node readiness check, drain
variable "await_node_readiness" { type = string }
#variable "expected_drain_count" { type = number }
variable "expected_node_count" { type = number }
variable "restore_wls_archives" { type = string }
variable "text_to_replace_in_config" {
  type = any
  default= {}
}
variable "wls_domain_path" {
  type = string
  default = "none"
}
#variable "wlsserver_instance_private_ips" { type = any }
#variable "worker_drain_ignore_daemonsets" { type = bool }
#variable "worker_drain_delete_local_data" { type = bool }
#variable "worker_drain_timeout_seconds" { type = number }
variable "user" {
  type = string
}
variable "group" {
  type = string
}

#TODO : JOI : pre-release delete default for user_id and group_id
variable "user_id" {
  type = number
}

variable "group_id" {
  type = number
}

#variable "bucket_name" {type = string}

variable "resource_name_prefix" {type = string}