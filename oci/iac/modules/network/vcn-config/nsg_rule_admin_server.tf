# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


resource "oci_core_network_security_group_security_rule" "wls_ingress_security_rule" {
  count                     = length(local.wls_admin_port_source_cidrs) > 0 ? length(local.wls_admin_port_source_cidrs) : 0
  network_security_group_id = element(var.nsg_ids["admin_nsg_id"], 0)
  direction                 = "INGRESS"
  protocol                  = "6"


  source      = local.wls_admin_port_source_cidrs[count.index]
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.wls_extern_ssl_admin_port
      min = var.wls_extern_ssl_admin_port
    }
  }
}


resource "oci_core_network_security_group_security_rule" "wls_admin_bastion_ingress_security_rule" {
  count                     = var.existing_bastion_instance_id == "" && var.is_bastion_instance_required && !var.assign_backend_public_ip ? 1 : 0
  network_security_group_id = element(var.nsg_ids["admin_nsg_id"], 0)
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = var.bastion_subnet_cidr
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.wls_extern_ssl_admin_port
      min = var.wls_extern_ssl_admin_port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "wls_admin_existing_bastion_ingress_security_rule" {
  count                     = var.existing_bastion_instance_id != "" && var.is_bastion_instance_required && !var.assign_backend_public_ip ? 1 : 0
  network_security_group_id = element(var.nsg_ids["admin_nsg_id"], 0)
  direction                 = "INGRESS"
  protocol                  = "6"

  source      = format("%s/32", data.oci_core_instance.existing_bastion_instance[count.index].private_ip)
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = var.wls_extern_ssl_admin_port
      min = var.wls_extern_ssl_admin_port
    }
  }
}



