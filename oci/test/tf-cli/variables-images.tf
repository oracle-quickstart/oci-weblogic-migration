# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


locals{
  marketplace_images_map={
    # Liting_ids and marketplace related variables are pre populated based on the discovered OS.
    byol = {
      listing_id = var.listing_id,
      listing_resource_version= var.listing_resource_version,
      instance_image_id = var.instance_image_id
      agreement_needed = false
    }
    ee-ucm = {
      listing_id = var.ucm_listing_id,
      listing_resource_version= var.ucm_listing_resource_version,
      instance_image_id = var.ucm_instance_image_id
      agreement_needed = true
    }
    suite-ucm = {
      listing_id = var.suite_ucm_listing_id,
      listing_resource_version= var.suite_ucm_listing_resource_version,
      instance_image_id = var.suite_ucm_instance_image_id
      agreement_needed = true
    }
    custom = {
      instance_image_id = var.wlsserver_image_custom_id
      agreement_needed = false
      vm_scripts_path = var.wlsoci_vmscripts_zip_bundle_path
    }
    platform = {
      # Should be from datsource
      instance_image_id = var.wlsserver_image_platform_id
      agreement_needed = false
      vm_scripts_path = var.wlsoci_vmscripts_zip_bundle_path
    }
  }

  marketplace_images_schema_map = zipmap(
    ["Oracle WebLogic Server BYOL Image", "Oracle WebLogic Server Enterprise Edition UCM Image", "Oracle Weblogic Suite UCM Image", "custom", "platform"],
    ["byol", "ee-ucm", "suite-ucm", "custom", "platform"]
  )

  image_type_selected_key          = local.marketplace_images_schema_map[var.wlsserver_image_type]
  vm_instance_image_id  = lookup(local.marketplace_images_map[local.image_type_selected_key],"instance_image_id","ohhh")
  listing_id_selected = lookup(local.marketplace_images_map[local.image_type_selected_key],"listing_id", "none")
  listing_resource_version_selected = lookup(local.marketplace_images_map[local.image_type_selected_key],"listing_resource_version","none")

  vm_instance_image_requirements = {
    tnc = var.terms_and_conditions
    agreement = lookup(local.marketplace_images_map[local.image_type_selected_key],"agreement_needed", false)
  }

  #  wlsserver_image_id   =  var.use_marketplace_image ? local.vm_instance_image_id: coalesce(var.wlsserver_image_custom_id, var.wlsserver_image_platform_id, "none")
  #  wlsserver_image_type = contains(["custom"], lower(var.wlsserver_image_type)) ? "custom" : contains(["Oracle WebLogic Server BYOL"], lower(var.wlsserver_image_type)) ? "ucm-ee":"ucm-suite"
  wlsserver_image_type =  lookup(local.marketplace_images_schema_map,var.wlsserver_image_type,null)
}

variable "wlsserver_image_platform_id" {
  default = null
  type    = string
}

variable "wlsserver_image_custom_id" {
  default = null
  type    = string
}

variable "instance_image_id" {
  type        = string
  description = "The OCID of the compute image used to create the WebLogic compute instances"
}

variable "use_bastion_marketplace_image" {
  type        = bool
  description = "Set to true if using a marketplace bastion image, to create the marketplace subscriptions"
  default     = true
}

variable "bastion_image_id" {
  type        = string
  description = "The OCID of the marketplace bastion image"
  default     = "ocid1.image.oc1..aaaaaaaablqmvpn633emdv7o2k42km6nxjt4i44aqwab3wxwquyz3ag6hvmq"
}

variable "bastion_listing_id" {
  type        = string
  description = "The OCID of the marketplace bastion image listing"
  default     = "ocid1.appcataloglisting.oc1..aaaaaaaacicjx6jviqczqow567tadr5ju7iy2m4vx6opyra6thql55n2nnvq"
}

variable "bastion_listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace bastion image listing resource version"
  default     = "23.2.3-ol8.7-23.04.25-230702-1"
}

variable "use_marketplace_image" {
  type        = bool
  description = "Set to true if using a marketplace WebLogic instance image, to create the marketplace subscriptions"
  default     = true
}

variable "listing_id" {
  type        = string
  description = "The OCID of the marketplace BYOL image listing"
}

variable "listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace BYOL image listing resource version"
}

variable "ucm_instance_image_id" {
  type        = string
  description = "The OCID of the marketplace Enterprise Edition UCM image which is used for provisioning"
}

variable "ucm_listing_id" {
  type        = string
  description = "The OCID of the marketplace Enterprise Edition UCM image listing"
}

variable "ucm_listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace Enterprise Edition UCM image listing resource version"
}

variable "suite_ucm_instance_image_id" {
  type        = string
  description = "The OCID of the marketplace Suite UCM image which is used for provisioning"
}

variable "suite_ucm_listing_id" {
  type        = string
  description = "The OCID of the marketplace Suite UCM image listing"
}

variable "suite_ucm_listing_resource_version" {
  type        = string
  description = "The OCID of the marketplace Suite UCM image listing resource version"
}

variable "wlsoci_vmscripts_zip_bundle_path" {
  type        = string
  description = "Absolute path to the wlsoci vmscripts zip bundle that is generated by the build"
}
