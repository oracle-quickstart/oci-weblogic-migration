# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

module "wls" {
  #source    = "github.com/oracle-terraform-modules/terraform-oci-wls.git?ref=5.x&depth=1"
  source ="../../../../iac2"
  providers = { oci.home = oci.home }

  # Identity
  tenancy_id     = var.tenancy_ocid
  compartment_id = var.compartment_ocid

  create_iam_resources         = true
  create_iam_autoscaler_policy = "never"
  create_iam_wlsserver_policy     = "never"

  #create_operator              = false
  # WLS Domain
  create_domain          = false

  # Bastion
  create_bastion               =  false
  bastion_public_ip =     ""

  # Network
  create_vcn     = false
  vcn_id         = ""
  assign_dns     = false


  subnets = {}

  nsgs = {}

  # Loadbalancer
  add_load_balancer=  false

  # Weblogic Servers
  ssh_public_key   = ""
  ssh_public_key_path = ""

  wlsserver_pools= {}

  wlsserver_image_type       = "custom"

  wlsserver_shape = {}

  #archive
  bucket_name = "testdomain"
  restore_wls_archives = "none"
  await_node_readiness = "none"

  #datasources
  wls_configured_datasource_text = local.datasources

  freeform_tags = {}

  defined_tags = {}
}