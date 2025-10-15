# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

variable "compartment_id" {
  description = "The compartment id where network resources will be created."
  type        = string
}

variable "wlsserver_vcn_id" {
  description = "Weblogic Virtual Cloud Network."
  type        = string
}

variable "wlsserver_count_expected" {
  description = "# of nodes expected from created wlsserver pools"
  type        = number
}

variable "wls_data" {
  description = "Weblogic Domain Inventory Data.JSON formatted"
  type        = any
}

variable "secondary_nodes_IPs" {
  description = "Private IPs of the (secondary)migrated domain instances"
  type        = list(string)
}

variable "source_nodes" {
  description = "List of hostnames (without zone suffix) for source nodes"
  type        = list(string)
}