# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

data "oci_objectstorage_bucket" "wls_archives" {
    name        = var.bucket_name
    namespace   = data.oci_objectstorage_namespace.oss_namespace.namespace

#  lifecycle {
#    precondition {
#      condition     = coalesce(var.bucket_name, "empty")=="empty"
#      error_message = <<-EOT
#      bucket name can't be null
#      EOT
#    }
#  }
}

data "oci_objectstorage_namespace" "oss_namespace" {
 #Optional
  compartment_id = var.tenancy_ocid
}

#TODO : JOI validate bucket_name is not null and is valid name.
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
