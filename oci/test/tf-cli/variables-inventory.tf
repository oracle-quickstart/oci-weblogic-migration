# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl


variable "wls_discovery_filename" {
  type        = string
  description = "Filename - JSON formated - with WLS domain discovered details"
  default     = "wlsdomain.json"
}

variable "wls_discovery_folder" {
  type        = string
  description = "Inventory folder"
  default     = "inventory"
}