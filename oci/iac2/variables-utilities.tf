# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

variable "await_node_readiness" {
  default     = "none"
  description = "Optionally block completion of Terraform apply until one/all worker nodes become ready."
  type        = string

  validation {
    condition     = contains(["none", "one", "all"], var.await_node_readiness)
    error_message = "Accepted values are 'none', 'one' or 'all'."
  }
}