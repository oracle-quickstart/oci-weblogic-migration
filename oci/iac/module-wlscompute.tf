# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


module "compute" {
  source                 = "./modules/compute/wls_compute"
  add_loadbalancer       = local.add_load_balancer
  is_lb_private          = var.is_lb_private
  load_balancer_id       = local.add_load_balancer ? (var.existing_load_balancer_id != "" ? var.existing_load_balancer_id : element(coalescelist(module.load-balancer[*].wls_loadbalancer_id, [""]), 0)) : ""
  assign_public_ip       = local.assign_weblogic_public_ip
  availability_domain    = local.wls_availability_domain
  compartment_id         = var.compartment_ocid
  instance_image_id      = local.vm_instance_image_id
  is_ucm_image           = var.terms_and_conditions
  instance_shape         = local.instance_shape
  network_compartment_id = var.network_compartment_id
  wls_subnet_cidr        = local.wls_subnet_cidr
  subnet_id              = var.wls_subnet_id != "" ? var.wls_subnet_id : local.assign_weblogic_public_ip ? element(concat(module.network-wls-public-subnet[*].subnet_id, [""]), 0) : element(concat(module.network-wls-private-subnet[*].subnet_id, [""]), 0)
  wls_subnet_id          = var.wls_subnet_id
  region                 = var.region
  ssh_public_key         = var.ssh_public_key
  tenancy_id                = var.tenancy_ocid
  use_regional_subnet       = local.use_regional_subnet

  # wls_14c_jdk_version       = "jdk11"
  #  wls_14c_jdk_version        = var.wls_14c_jdk_version
  ##

  #  wls_admin_user            = var.wls_admin_user

  resource_name_prefix = local.wls_domain_name
  wls_admin_server_name     = local.wls_adminserver_name
  wls_machines =  local.oci_instances

  wls_admin_port            = local.wls_admin_listen_port
  wls_admin_ssl_port        = local.wls_admin_ssl_port
  wls_domain_name           = format("%s_domain", local.service_name_prefix)
  #TODO: JOI Not used in V1.
  #  wls_server_startup_args   = var.wls_server_startup_args
  wls_existing_vcn_id       = var.wls_existing_vcn_id

  #The following two are for adding a dependency on the peering module
  #  wls_vcn_peering_dns_resolver_id           = element(flatten(concat(module.vcn-peering[*].wls_vcn_dns_resolver_id, [""])), 0)
  #  wls_vcn_peering_route_table_attachment_id = local.assign_weblogic_public_ip ? element(flatten(concat(module.vcn-peering[*].wls_vcn_public_route_table_attachment_id, [""])), 0) : element(flatten(concat(module.vcn-peering[*].wls_vcn_private_route_table_attachment_id, [""])), 0)

  #  mount_vcn_id                  = var.mount_target_id != "" ? data.oci_core_subnet.mount_target_existing_subnet[0].vcn_id : ""
  wls_vcn_cidr                  = var.wls_vcn_cidr != "" ? var.wls_vcn_cidr : data.oci_core_vcn.wls_vcn[0].cidr_block
  allow_manual_domain_extension = false
  #TODO: JOI remove
  #  num_vm_instances              = var.wls_node_count
  num_vm_instances              = length(local.wls_machines)

  is_bastion_instance_required = false

  lbip = local.lb_ip

  #add_fss     = false # var.add_fss
  #mount_ip    = "0.0.0.0" # var.existing_fss_id != "" ? element(concat(data.oci_core_private_ip.mount_target_private_ips.*.ip_address, [""]), 0) : element(concat(module.fss[*].mount_ip, [""]), 0)
  #mount_path  = "" #var.mount_path
  #export_path = "" #local.export_path
  #TODO: JOI not used in V1.
  #  db_existing_vcn_add_seclist = var.db_existing_vcn_add_secrule
  #db_existing_vcn_add_seclist = false
  #  jrf_parameters = {
  ##    db_user        = local.db_user
  ##    db_password_id = local.db_password_id
  ##    atp_db_parameters = {
  ##      atp_db_id    = var.atp_db_id
  ##      atp_db_level = var.atp_db_level
  ##    }
  ##    oci_db_parameters = {
  ##      oci_db_connection_string      = var.oci_db_connection_string
  ##      oci_db_compartment_id         = local.oci_db_compartment_id
  ##      oci_db_dbsystem_id            = trimspace(var.oci_db_dbsystem_id)
  ##      oci_db_database_id            = var.oci_db_database_id
  ##      oci_db_pdb_service_name       = var.oci_db_pdb_service_name
  ##      oci_db_port                   = var.oci_db_port
  ##      oci_db_network_compartment_id = local.oci_db_network_compartment_id
  ##      oci_db_existing_vcn_id        = var.oci_db_existing_vcn_id
  ##    }
  #  }

  use_marketplace_image       = var.use_marketplace_image
  mp_listing_id               = var.listing_id
  mp_listing_resource_version = var.listing_resource_version

  mp_ucm_listing_id               = var.ucm_listing_id
  mp_ucm_listing_resource_version = var.ucm_listing_resource_version

#  tags = {
#    defined_tags    = local.defined_tags
#    freeform_tags   = local.free_form_tags
#    dg_defined_tags = local.dg_defined_tags
#  }
  wls_ms_ports          = local.wls_managed_server_ports
  wls_ms_server_details = local.wls_managed_server_details
}