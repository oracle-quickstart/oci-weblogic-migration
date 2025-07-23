# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Common

variable "state_id" {
  default     = null
  description = "Optional Terraform state_id from an existing deployment of the module to re-use with created resources."
  type        = string
}

variable "compartment_id" {
  default     = null
  description = "The compartment id where resources will be created."
  type        = string
}

variable "tenancy_id" {
  default     = null
  description = "The tenancy id of the OCI Cloud Account in which to create the resources."
  type        = string
}

# Tags

variable "freeform_tags" {
  default     = {}
  description = "Freeform tags to be applied to created resources."
  type        = map(string)
}

variable "defined_tags" {
  default     = {}
  description = "Defined tags to be applied to created resources. Must already exist in the tenancy."
  type        = map(string)
}

variable "use_defined_tags" {
  default     = false
  description = "Whether to apply defined tags to created resources for IAM policy and tracking."
  type        = bool
}

variable "tag_namespace" {
  default     = "wls"
  description = "The tag namespace for standard Weblogic defined tags."
  type        = string
}


variable "wlsdomain_dns" {
  default     = null
  description = "WLS Domain DNS resolver IP address. Determined automatically when not set (recommended)."
  type        = string
}

# Network

variable "assign_dns" { type = bool }
variable "assign_public_ip" { type = bool }
variable "wlsserver_subnet_id" { type = string }
variable "wlsserver_vcn_id" { type = string }
#variable "is_vcn_peering" { type = bool }
#variable "db_subnet_id" { type = string }
variable "wlsserver_lpg" { type = string }
variable "db_lpg" { type = string }

# Weblogic Server pools is a TF grouping to defined common defaults for different Weblogic Machines.
variable "wlsserver_pools" {
#  default     = {}
  description = "Tuple of Weblogic Machines grouped as logical pools.  Each key maps to the OCID of an OCI resource, and value contains its definition."
  type        = any
}

variable "wlsserver_pool_mode" {
  default     = "instance"
  description = "Default management mode for wlsservers when unspecified on a pool. Only 'node-pool' is currently supported."
  type        = string
  validation {
    condition     = contains(["instance", "instance-pool"], var.wlsserver_pool_mode)
    error_message = "Accepted values are instance.  Future Version to include instance-pool"
  }
}

variable "wlsserver_pool_size" {
  default     = 0
  description = "Default size for wlsserver pools when unspecified on a pool."
  type        = number
}

# wlsservers: instance

variable "ad_numbers_to_names" { type = map(string) }
variable "ad_numbers" { type = list(number) }

variable "image_ids" {
  default     = {}
  description = "Map of images for filtering with image_os and image_os_version."
  type        = any
}

variable "ssh_public_key" {
  default     = null
  description = "The contents of the SSH public key file. Used to allow login for wlsservers/bastion/operator with corresponding private key."
  type        = string
}

variable "timezone" { type = string }

variable "managedserver_nsg_ids" {
  default     = []
  description = "An additional list of network security group (NSG) IDs for node security. Combined with 'nsg_ids' specified on each pool."
  type        = list(string)
}

variable "adminserver_nsg_ids" {
  default     = []
  description = "An additional list of network security group (NSG) IDs for pod security. Combined with 'pod_nsg_ids' specified on each pool."
  type        = list(string)
}

variable "wls_data" {
  type =  any
  description = "Weblogic Domain Inventory Data.JSON formated "
}

#
# wlsservers: instance
#

variable "block_volume_type" {
  default     = "paravirtualized"
  description = "Default block volume attachment type for Instance Configurations when unspecified on a pool."
  type        = string
  validation {
    condition     = contains(["iscsi", "paravirtualized"], var.block_volume_type)
    error_message = "Accepted values are 'iscsi' or 'paravirtualized'."
  }
}

variable "node_labels" {
  default     = {}
  description = "Default wlsserver node labels. Merged with labels defined on each pool."
  type        = map(string)
}


variable "node_metadata" {
  default     = {}
  description = "Map of additional wlsserver node instance metadata. Merged with metadata defined on each pool."
  type        = map(string)
}

#TODO (joi) introduced change.. removed default
variable "image_id" {
#  default     = null
  description = "Default image for Weblogic Nodes when not specified as a list of images in variable image_ids"
  type        = string
}

variable "image_type" {
  default     = "platform"
  description = "Whether to use a platform, Weblogic, or custom image for wlsserver nodes by default. When custom is set, the wlsserver_image_id must be specified."
  type        = string
  validation {
    condition     = contains(["custom", "ee-byol", "suite-byol", "ee-ucm", "suite-ucm" , "platform"], var.image_type)
    error_message = "Accepted values are custom, ee-byol, suite-byol, ee-ucm, suite-ucm, platform"
  }
}

variable "image_os" {
  default     = "Oracle Linux"
  description = "Default wlsserver image operating system name when wlsserver_image_type = 'wls' or 'platform' and unspecified on a pool."
  type        = string
}

variable "image_os_version" {
  default     = "8"
  description = "Default wlsserver image operating system version when wlsserver_image_type = 'wls' or 'platform' and unspecified on a pool."
  type        = string
}

variable "shape" {
  default = {
    shape            = "VM.Standard.E4.Flex",
    ocpus            = 2,
    memory           = 16,
    boot_volume_size = 50
  }
  description = "Default shape of the created wlsserver instance when unspecified on a pool."
  type        = map(any)
}

variable "capacity_reservation_id" {
  default     = null
  description = "The ID of the Compute capacity reservation the wlsserver node will be launched under. See <a href=https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/reserve-capacity.htm>Capacity Reservations</a> for more information."
  type        = string
}


variable "cloud_init" {
  default     = []
  description = "List of maps containing cloud init MIME part configuration for wlsserver nodes. Merged with pool-specific definitions. See https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config.html#part for expected schema of each element."
  type        = list(map(string))
}

variable "disable_default_cloud_init" {
  default     = false
  description = "Whether to disable the default Weblogic cloud init and only use the cloud init explicitly passed to the wlsserver pool in 'wlsserver_cloud_init'."
  type        = bool
}

variable "volume_kms_key_id" {
  default     = null
  description = "The ID of the OCI KMS key to be used as the master encryption key for Boot Volume and Block Volume encryption by default when unspecified on a pool."
  type        = string
}

variable "pv_transit_encryption" {
  default     = false
  description = "Whether to enable in-transit encryption for the data volume's paravirtualized attachment by default when unspecified on a pool."
  type        = bool
}

variable "max_pods_per_node" {
  default     = 31
  description = "The default maximum number of pods to deploy per node when unspecified on a pool. Absolute maximum is 110. Ignored when when cni_type != 'npn'."
  type        = number

  validation {
    condition     = var.max_pods_per_node > 0 && var.max_pods_per_node <= 110
    error_message = "Must be between 1 and 110."
  }
}

variable "platform_config" {
  default     = null
  description = "Default platform_config for self-managed wlsserver pools created with mode: 'instance', 'instance-pool', or 'cluster-network'. See <a href=https://docs.oracle.com/en-us/iaas/api/#/en/iaas/20160918/datatypes/PlatformConfig>PlatformConfig</a> for more information."
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

variable "storage_freeform_tags" {
  default = {}
}
variable "storage_defined_tags" {
  default = {}
}

variable "user" {
  type = string
  default = "oracle"
}
variable "group" {
  type = string
  default = "oracle"
}

#TODO : JOI : pre-release delete default for user_id and group_id
variable "user_id" {
  type = number
  default = 1001
}

variable "group_id" {
  type = number
  default = 1001
}

variable "wlsserver_ports" { type = list(string)}
variable "adminserver_ports" { type = list(string)}
variable "bucket_name" {type = string}


#WLS Domain Details
variable "wls_datasources_config" {type = any}
variable "wls_domain_home" {type = string}
variable "resource_name_prefix" {
  type        = string
  description = "Prefix/or WLS Domain Name used in OCI instance of which this compute is part"
}

variable "wls_archived_volumes" {
  type        = any
  description = "List of volumes to be mounted in the compute instance. Each element must be an object with the following attributes: volume_mount_point, display_name, device"
}

variable "stage_archive_path" {
  type = string
  description = "Path inside the OS to stage all archives downloaded from Object Storage. Defaults to /tmp"
  default = "/tmp"
}

variable "is_development" {
  type = bool
  default = false
}

variable "mode" {
  type = string
  default = "PROD"
}
variable "vm_scripts_path" {
  type =  string
  default = ""
}

variable "text_to_replace_in_config" {
  type = any
  default= {}
}