# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

variable "create_bastion" {
  default     = false
  description = "Whether to create a bastion host."
  type        = bool
}