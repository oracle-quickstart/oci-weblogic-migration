# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

# Test file for Terraform.

# Refactor moved to variables_bastion.tf
#variable "bastion_image_id" {
#  type        = string
#  description = "The OCID of the marketplace bastion image"
#  default     = "ocid1.image.oc1..aaaaaaaablqmvpn633emdv7o2k42km6nxjt4i44aqwab3wxwquyz3ag6hvmq"
#}
variable "compartment_ocid" {
  type        = string
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


#TODO: Refactor markeplace listing id.
variable "bastion_image_id" {
  #  default     = null
  default     = "ocid1.image.oc1..aaaaaaaablqmvpn633emdv7o2k42km6nxjt4i44aqwab3wxwquyz3ag6hvmq"
  description = "Image ID for created bastion instance."
  type        = string
}

#Get Image Agreement
resource "oci_core_app_catalog_listing_resource_version_agreement" "bastion_mp_image_agreement" {
  listing_id               = var.bastion_listing_id
  listing_resource_version = var.bastion_listing_resource_version
}

##Accept Terms and Subscribe to the image, placing the image in a particular compartment
resource "oci_core_app_catalog_subscription" "bastion_mp_image_subscription" {
  compartment_id           = var.compartment_ocid
#  compartment_id = var.tenancy_id
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.bastion_mp_image_agreement.eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.bastion_mp_image_agreement.listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.bastion_mp_image_agreement.listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.bastion_mp_image_agreement.oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.bastion_mp_image_agreement.signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.bastion_mp_image_agreement.time_retrieved

  timeouts {
    create = "20m"
  }
}

