# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

data "oci_objectstorage_namespace" "oss_namespace" {
 #Optional
  compartment_id = var.tenancy_ocid
}

data "oci_objectstorage_bucket" "wls_archives" {
  name        = var.bucket_name
  namespace   = data.oci_objectstorage_namespace.oss_namespace.namespace
}

variable "bucket_name" {
  type        = string
  description = "OCI Object Storage bucket id"
  default     = null
}
variable "bucket_compartment"{
  type        = string
  description = "OCI bucket storage compartment id"
  default     = null
}

locals {
  validators_msg_map = {
    #Dummy map to trigger an error in case we detect a validation error.
  }
  invalid_bucket_msg   = "Terraform-ERROR: The value for bucket_name=[${var.bucket_name}] is invalid. Verify the bucket exists in OCI."
  validate_bucket_name = data.oci_objectstorage_bucket.wls_archives.id == null ? local.validators_msg_map[local.invalid_bucket_msg] : null
}