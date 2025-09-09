# Copyright (c) 2024, 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

variable "create_bastion" { default = true }
variable "bastion_is_public" { default = true }
variable "bastion_upgrade" { default = false }

variable "bastion_allowed_cidrs" {
  default = ["0.0.0.0/0"]
  type    = list(string)
}

variable "bastion_availability_domain" {
  default = null
  type    = string
}

variable "bastion_user" {
  default = "opc"
  type    = string
}

variable "bastion_image_type" {
  default = "platform"
  type    = string
  validation {
    condition     = contains(["custom", "platform"], lower(var.bastion_image_type))
    error_message = "Accepted values are custom or platform"
  }
}

variable "bastion_image_os" {
  default = "Oracle Linux"
  type    = string
}

variable "bastion_image_os_version" {
  default = "8"
  type    = string
}

variable "bastion_shape" {
  type = object({
    instanceShape     = string
    ocpus             = number
    memory            = number
  })
  default = {
    instanceShape     = "VM.Standard.E4.Flex"
    ocpus             = 1
    memory            = 16
  }
}

variable "bastion_tags" {
  default = {}
  type    = map(any)
}

variable "bastion_shape_boot" {
  default = 50
}