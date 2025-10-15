# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
#
#
#variable "use_bastion_marketplace_image" {
#  type        = bool
#  description = "Set to true if using a marketplace bastion image, to create the marketplace subscriptions"
#  default     = true
#}
#
#variable "bastion_listing_id" {
#  type        = string
#  description = "The OCID of the marketplace bastion image listing"
#  default     = "ocid1.appcataloglisting.oc1..aaaaaaaacicjx6jviqczqow567tadr5ju7iy2m4vx6opyra6thql55n2nnvq"
#}
#
#variable "bastion_listing_resource_version" {
#  type        = string
#  description = "The OCID of the marketplace bastion image listing resource version"
#  default     = "23.2.3-ol8.7-23.04.25-230702-1"
#}
#
#variable "use_marketplace_image" {
#  type        = bool
#  description = "Set to true if using a marketplace WebLogic instance image, to create the marketplace subscriptions"
#}
#
#variable "instance_image_id" {
#  type        = string
#  description = "The OCID of the compute image used to create the WebLogic compute instances"
#  default     = ""
#}
#
#variable "mp_listing_id" {
#  type        = string
#  description = "The OCID of the marketplace BYOL image listing"
#}
#
#variable "mp_listing_resource_version" {
#  type        = string
#  description = "The OCID of the marketplace BYOL image listing resource version"
#}
#

#vm_instance_image_requirements = {
#  tnc = var.terms_and_conditions
#  agreement = lookup(local.marketplace_images_map[local.image_type_selected_key],"agreement_needed", false)
#}

variable "image_instance_requirements" {
  type        = any
  description = "The metadata info to send it to instance to determine if its ucm image based instance or not"
  validation {
    condition = var.image_instance_requirements.agreement ? var.image_instance_requirements.tnc ? true : false: true
    error_message = "Must accept Terms and Conditions for UCM Image selected"
  }
}