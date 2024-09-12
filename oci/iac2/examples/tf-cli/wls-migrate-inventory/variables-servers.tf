# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Identity

# Automatically populated by Resource Manager

variable "create_iam_wlsserver_policy" { default = false }


# Worker pools
variable "wlsserver_pool_mode" {
  default = "Instances"
  type    = string
  validation {
    condition     = contains(["Instances", "Instance Pool"], var.wlsserver_pool_mode)
    error_message = "Accepted values are Instances. Instance Pool may be included in a future release"
  }
}
variable "wlsserver_pool_size" {
  default = 1
  type    = number
}


# Workers: instance

variable "wlsserver_block_volume_type" { type = string }
variable "wlsserver_node_labels" {
  default = {}
  type    = map(string)
}

#TODO: Change to Oracle Weblogic Suite UCM Image as default on release
variable "wlsserver_image_type" {
  type        = string
  description = "Type of image used for provisioning. Image type must be BYOL or UCM"
  default     = "Oracle WebLogic Server BYOL"
  validation {
    condition     = contains(["Oracle WebLogic Server BYOL", "Oracle Weblogic Suite UCM", "Oracle WebLogic Server Enterprise Edition UCM", "Custom"], var.wlsserver_image_type)
    error_message = "WLSC-ERROR: Allowed values for Weblogic Edition are 'Oracle WebLogic Server BYOL' or 'Oracle Weblogic Suite UCM' or 'Oracle WebLogic Server Enterprise Edition UCM' or 'Custom' "
  }
}

variable "terms_and_conditions" {
  type        = bool
  description = "Terms and conditions for user to accept Oracle WebLogic Server Enterprise Edition UCM or Oracle WebLogic Suite UCM license agreement"
  default     = false
}

variable "wlsserver_image_id" {
  default = null
  type    = string
}
variable "wlsserver_image_os" {
  default = "Oracle Linux"
  type    = string
}
variable "wlsserver_image_os_version" {
  default = "8"
  type    = string
}


variable "wlsserver_shape" { default = "VM.Standard.E4.Flex" }
variable "wlsserver_ocpus" { default = 2 }
variable "wlsserver_memory" { default = 16 }
variable "wlsserver_boot_volume_size" { default = 50 }
variable "wlsserver_pv_transit_encryption" { default = false }

variable "wlsserver_cloud_init_configure" {
  type = bool
  default = true
}
variable "wlsserver_cloud_init_wls" {
  default = <<-EOT
  #!/usr/bin/env bash
  curl --fail -H "Authorization: Bearer Oracle" -L0 http://169.254.169.254/opc/v2/instance/metadata/wls_init_script | base64 --decode >/var/run/wls-init.sh
  bash /opt/scripts/bootstrap.sh
  EOT
  type    = string
}
variable "wlsserver_cloud_init_byon" {
  default = <<-EOT
  #!/usr/bin/env bash
  /opt/scripts/bootstrap.sh
  EOT
  type    = string
}

variable "wlsserver_volume_kms_key_id" {
  default = null
  type    = string
}
variable "wlsserver_volume_kms_vault_id" {
  default = null
  type    = string
}

variable "wlsserver_image_platform_id" {
  default = null
  type    = string
}
variable "wlsserver_image_custom_id" {
  default = null
  type    = string
}

variable "wlsserver_tags" {
  default = {}
  type    = map(any)
}

variable "create_domain" {
  default = true
  type = bool
}

variable "add_load_balancer" {
  default = false
  type = bool
}

#Pools is just a grouping of WLS Servers. Create either by pool definition for common attributes or per instance
variable "wlsserver_pools" {
  default     = {}
  description = "Tuple of Weblogic Server definitions grouped as pools. where each key maps to the OCID of an OCI resource, and value contains its definition."
  type        = any
}

variable "bucket_name" {
  description = "Object Storage Bucket name where WLS archives are stored."
  type = string
}
