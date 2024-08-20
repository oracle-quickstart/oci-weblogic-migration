# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#variable "wls_ms_content_port" {
#  type        = number
#  description = "The managed server port or idcs cloudgate port for application traffic"
#}

variable "wls_ms_source_cidrs" {
  type        = list(any)
  description = "The WebLogic managed servers source CIDR values"
}

variable "wls_managed_server_ports" {
  type        = list(any)
  description = "The WebLogic managed servers Listen Ports"
}