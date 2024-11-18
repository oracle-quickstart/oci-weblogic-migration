# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


#
# wlsservers: network
#

variable "custom_dns" {
  default     = null
  description = "Cluster DNS resolver IP address. Determined automatically when not set (recommended)."
  type        = string
}


variable "wlsserver_is_public" {
  default     = false
  description = "Whether to provision wlsservers with public IPs allocated by default when unspecified on a pool."
  type        = bool
}

#variable "managedserver_nsg_ids" {
#  default     = []
#  description = "An additional list of network security group (NSG) IDs for node security for every Weblogic Mananged Server. Combined with 'nsg_ids' specified on each pool."
#  type        = list(string)
#}
#
#variable "adminserver_nsg_ids" {
#  default     = []
#  description = "An additional list of network security group (NSG) IDs for node security for every Weblogic Admin Server. Combined with 'nsg_ids' specified on each pool."
#  type        = list(string)
#}

#Pools is just a grouping of WLS Servers. Create either by pool definition for common attributes or per instance
variable "wlsserver_pools" {
#  default     = {}
  description = "Tuple of Weblogic Server definitions grouped as pools. where each key maps to the OCID of an OCI resource, and value contains its definition."
  type        = any
}

#
# wlsservers: instance
#

variable "wlsserver_block_volume_type" {
  default     = "paravirtualized"
  description = "Default block volume attachment type for Instance Configurations when unspecified on a pool."
  type        = string
  validation {
    condition     = contains(["iscsi", "paravirtualized"], var.wlsserver_block_volume_type)
    error_message = "Accepted values are 'iscsi' or 'paravirtualized'."
  }
}

variable "wlsserver_node_labels" {
  default     = {}
  description = "Default wlsserver node labels. Merged with labels defined on each pool."
  type        = map(string)
}

variable "wlsserver_node_metadata" {
  default     = {}
  description = "Map of additional wlsserver node instance metadata. Merged with metadata defined on each pool."
  type        = map(string)
}

variable "wlsserver_image_id" {
  default     = null
  description = "Default image for wlsserver pools  when unspecified on a pool."
  type        = string
}

variable "wlsserver_image_type" {
  type        = string
  description = "Type of image used for provisioning. Image type must be BYOL or UCM"
  default     = "byol"
  validation {
    condition     = contains(["byol","platform", "suite-ucm", "ee-ucm", "custom"], var.wlsserver_image_type)
    error_message = "WLSC-ERROR: Weblogic image type not a valid value."
  }
}


variable "wlsserver_image_os" {
  default     = "Oracle Linux"
  description = "Default wlsserver image operating system name when wlsserver_image_type = 'marketplace' or 'platform'"
  type        = string
}

variable "wlsserver_image_os_version" {
  default     = "8"
  description = "Default wlsserver image operating system version when wlsserver_image_type = 'marketplace' or 'platform' "
  type        = string
}

variable "wlsserver_shape" {
  default = {
    shape            = "VM.Standard.E4.Flex"
    ocpus            = 2
    memory           = 16
    boot_volume_size = 50

    # https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/blockvolumeperformance.htm
    # Supported for mode = "cluster-network" | "instance-pool" | "instance" (self-managed) only
    boot_volume_vpus_per_gb = 10 # 10: Balanced, 20: High, 30-120: Ultra High (requires multipath)
  }
  description = "Default shape of the created wlsserver instance when unspecified on a pool."
  type        = map(any)
}


variable "wlsserver_cloud_init" {
  default     = []
  description = "List of maps containing cloud init MIME part configuration for wlsserver nodes.  See https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config.html#part for expected schema of each element."
  type        = list(map(string))
}

#TODO: JOI - Cloud init per weblogic type (AS or MS) ? Remove ?
variable "wlsserver_disable_default_cloud_init" {
  default     = false
  description = "Whether to disable the default cloud init and only use the cloud init explicitly passed to the wlsserver pool in 'wlsserver_cloud_init'."
  type        = bool
}

variable "wlsserver_volume_kms_key_id" {
  default     = null
  description = "The ID of the OCI KMS key to be used as the master encryption key for Boot Volume and Block Volume encryption."
  type        = string
}

variable "wlsserver_pv_transit_encryption" {
  default     = false
  description = "Whether to enable in-transit encryption for the data volume's paravirtualized attachment by default."
  type        = bool
}

variable "wlsserver_mw_volume_size" { default = 101 }
variable "wlsserver_jdk_volume_size" { default = 52 }
variable "wlsserver_domain_volume_size" { default = 253 }


variable "platform_config" {
  default     = null
  description = "Default platform_config for Managed Servers created with mode: 'instance'. See <a href=https://docs.oracle.com/en-us/iaas/api/#/en/iaas/20160918/datatypes/PlatformConfig>PlatformConfig</a> for more information."
  type = object({
    type                                           = optional(string),
    are_virtual_instructions_enabled               = optional(bool),
    is_access_control_service_enabled              = optional(bool),
    is_input_output_memory_management_unit_enabled = optional(bool),
    is_measured_boot_enabled                       = optional(bool),
    is_memory_encryption_enabled                   = optional(bool),
    is_secure_boot_enabled                         = optional(bool),
    is_symmetric_multi_threading_enabled           = optional(bool),
    is_trusted_platform_module_enabled             = optional(bool),
    numa_nodes_per_socket                          = optional(number),
    percentage_of_cores_enabled                    = optional(bool),
  })
}

#variable "agent_config" {
#  default     = null
#  description = "Default agent_config for  Managed Servers created with mode: 'instance'. See <a href=https://docs.oracle.com/en-us/iaas/api/#/en/iaas/20160918/datatypes/InstanceAgentConfig for more information."
#  type = object({
#    are_all_plugins_disabled = bool,
#    is_management_disabled   = bool,
#    is_monitoring_disabled   = bool,
#    plugins_config           = map(string),
#  })
#}