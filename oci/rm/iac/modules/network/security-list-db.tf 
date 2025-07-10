# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "oci_core_security_list" "wls_to_db" {
  count = var.create_db_ingress_sl ? 1 : 0

  compartment_id = var.db_network_compartment_id
  vcn_id         = var.db_existing_vcn_id
  display_name   = "wls-to-db-security-list"

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.wlsserver_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
    description = "Allow WLS subnet to access DB port 1521"

    tcp_options {
      min = var.oci_db_port_0
      max = var.oci_db_port_0
    }
  }
}

output "wls_to_db_security_list_id" {
  value       = try(oci_core_security_list.wls_to_db[0].id, null)
  description = "Security List OCID that allows WLS to connect to DB"
}
