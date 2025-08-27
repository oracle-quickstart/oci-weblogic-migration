# Copyright (c) 2025, Oracle Corporation and/or affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

variable "compartment_id" {
  description = "The compartment id where network resources will be created."
  type        = string
}

variable "wlsserver_vcn_id" {
  description = "Weblogic Virtual Cloud Network."
  type        = string
}

variable "forward_dns_records" {
  type = map(string)
}

variable "reverse_ptr_records" {
  type = map(string)
}
