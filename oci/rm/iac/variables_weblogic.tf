# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl


variable "create_domain" {
  default = true
  description = "Whether to create OCI Instances and restore WLS Servers backups"
  type = bool
}

variable "wls_expose_admin_port" {
  type        = bool
  description = "[WARNING] Selecting this option will expose the console to the internet if the default 0.0.0.0/0 CIDR is used. You should change the CIDR range below to allow access to a trusted IP range."
  default     = false
}
#
variable "wls_admin_port_source_cidr" {
  type        = string
  description = "Create a security list to allow access to the WebLogic Administration Console port to the source CIDR range. [WARNING] Keeping the default 0.0.0.0/0 CIDR will expose the console to the internet. You should change the CIDR range to allow access to a trusted IP range."
  default     = "0.0.0.0/0"
}

variable "wls_configured_datasource_text" {
  type = any
  default = {}
  description = "Map with Datasource on-prem text and new oci value. "
}
