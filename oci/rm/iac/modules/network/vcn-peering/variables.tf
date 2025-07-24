# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "datasources" {
  type        = any
  default     = {}
  description = "Map with Datasource on-prem text and new oci value. "
}

variable "compartment_id" {
  description = "The compartment id where network resources will be created."
  type        = string
}

variable "vcn_id" {
  description = "Weblogic Virtual Cloud Network."
  type        = string
}

variable "lpg_name" {
  type        = string
  description = "A user-friendly lpg name"
}

variable "wlsserver_subnet_id" {
  type    = string
}
