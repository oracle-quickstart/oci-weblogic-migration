# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

output "rms_private_endpoint_id" {
  value       = oci_resourcemanager_private_endpoint.rms_private_endpoint.id
  description = "The OCID of the resource manager private endpoint"
}
