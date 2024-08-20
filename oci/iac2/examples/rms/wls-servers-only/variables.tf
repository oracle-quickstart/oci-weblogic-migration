# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Identity

# Automatically populated by Resource Manager
variable "tenancy_ocid" { type = string }
variable "current_user_ocid" { type = string }
variable "compartment_ocid" { type = string }
variable "region" { type = string }
variable "use_defined_tags" {
  default     = false
  description = "Add existing tags in the configured namespace to created resources when applicable."
  type        = bool
}

variable "tag_namespace" {
  default     = "wls"
  description = "Tag namespace containing standard tags for resources created by the module: [state_id, wlsservers]."
  type        = string
}

variable "create_iam_autoscaler_policy" { default = false }
variable "create_iam_wlsserver_policy" { default = false }
variable "autoscale" { default = false }

# Cluster

variable "cluster_id" {
  default = null
  type    = string
}
variable "cni_type" { default = "Flannel" }
variable "kubernetes_version" {
  default = "v1.26.2"
  type    = string
}

#TODO: JOI remove.
# wlsserver pools
variable "wlsserver_pool_mode" {
  default = "Instances"
  type    = string
  validation {
    condition     = contains(["Instances", "Instance Pool"], var.wlsserver_pool_mode)
    error_message = "Accepted values are Instances. Future service: Instance Pool, Instance Configuration"
  }
}
variable "wlsserver_pool_size" {
  default = 1
  type    = number
}

# wlsservers: network

variable "vcn_id" {
  default = null
  type    = string
}
variable "assign_dns" { default = true }
variable "adminserver_nsg_id" { default = "" }
variable "wlsserver_nsg_id" { default = "" }
variable "wlsserver_subnet_id" { type = string }
variable "kubeproxy_mode" { type = string }

# wlsservers: instance

variable "wlsserver_block_volume_type" { type = string }
variable "wlsserver_node_labels" {
  default = {}
  type    = map(string)
}
variable "wlsserver_image_type" { type = string }
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

variable "wlsserver_pool_name" { type = string }

variable "wlsserver_shape" { default = "VM.Standard.E4.Flex" }
variable "wlsserver_ocpus" { default = 2 }
variable "wlsserver_memory" { default = 16 }
variable "wlsserver_boot_volume_size" { default = 50 }
variable "wlsserver_pv_transit_encryption" { default = false }

variable "wlsserver_cloud_init_configure" { type = bool }

variable "wlsserver_cloud_init_wls" {
  default = <<-EOT
  #!/usr/bin/env bash
  curl --fail -H "Authorization: Bearer Oracle" -L0 http://169.254.169.254/opc/v2/instance/metadata/wls_init_script | base64 --decode >/var/run/wls-init.sh
  bash /etc/wls/wls-install.sh
  EOT
  type    = string
}

variable "wlsserver_cloud_init_byon" {
  default = <<-EOT
  #!/usr/bin/env bash
  #apiserver_host="10.0.0.1"
  #ca_base64="LS0tLS1...LS0tCg==" # kubectl config view --raw -o json | jq -rcM '.clusters[0].cluster["certificate-authority-data"]'
  bash /etc/wls/wls-install.sh --apiserver-endpoint "$\{apiserver_host}" --kubelet-ca-cert "$\{ca_base64}"
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