  #TODO: JOI New refactored
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


variable "is_rms_private_endpoint_required" {
  type        = bool
  description = "Set resource manager private endpoint. Default value is true"
  default     = true
}

variable "add_rms_private_endpoint" {
  type        = string
  description = "Add existing resource manager private endpoint"
  default     = "Use Existing Resource Manager Endpoint"
}

variable "rms_existing_private_endpoint_id" {
  type        = string
  description = "The OCID for the existing resource manager private endpoint"
  default     = ""
}