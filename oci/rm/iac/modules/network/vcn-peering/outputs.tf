# Copyright (c) 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

output "db_lpg" {
  value = oci_core_local_peering_gateway.dblpg_0[*].id
}

output "wls_lpg" {
  value = oci_core_local_peering_gateway.wlslpg_0[*].id
}
