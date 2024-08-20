# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


locals {
  port_for_ingress_lb_security_rule = 443
  wls_admin_port_source_cidrs       = var.wls_expose_admin_port ? [var.wls_admin_port_source_cidr] : []
  nat_gw_exists                     = length(var.existing_nat_gateway_ids) == 0 ? false : true
}

# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  # Port numbers
  all_ports               = -1
  fss_nfs_portmapper_port = 111
  fss_nfs_port_min        = 2048
  fss_nfs_port_max        = 2050
  health_check_port       = 10256
  ssh_port                = 22
  wlsconsole_port         = 7001
  administrative_port     = 9071


  # Protocols
  # See https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
  all_protocols = "all"
  icmp_protocol = 1
  tcp_protocol  = 6
  udp_protocol  = 17

  anywhere          = "0.0.0.0/0"
  rule_type_nsg     = "NETWORK_SECURITY_GROUP"
  rule_type_cidr    = "CIDR_BLOCK"
  rule_type_service = "SERVICE_CIDR_BLOCK"

  # Oracle Services Network (OSN)
  osn = one(data.oci_core_services.all_oci_services.services[*].cidr_block)
}