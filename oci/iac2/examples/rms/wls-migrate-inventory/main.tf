#Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  wlsserver_image_id   = coalesce(var.wlsserver_image_custom_id, var.wlsserver_image_platform_id, "none")
  wlsserver_image_type_map = {
    "custom": "custom",
    "Oracle WebLogic Server BYOL": "platform"
    "Oracle Weblogic Suite UCM" : "suite-ucm"
    "Oracle WebLogic Server Enterprise Edition UCM": "ee-ucm"
  }
  #wlsserver_image_type = contains(["custom"], lower(var.wlsserver_image_type)) ? "custom" : contains(["Oracle WebLogic Server BYOL"], lower(var.wlsserver_image_type)) ? "ucm-ee":"ucm-suite"
  wlsserver_image_type = lookup(local.wlsserver_image_type_map,var.wlsserver_image_type,null)

  wlsserver_cloud_init = var.wlsserver_cloud_init_configure ? [{
    content_type = "text/x-shellscript",
    content      = var.wlsserver_cloud_init_byon
  }] : []
}



module "wls" {
  #source    = "github.com/oracle-terraform-modules/terraform-oci-wls.git?ref=5.x&depth=1"
  source ="../../../../iac2"
  providers = { oci.home = oci.home }

  # Identity
  tenancy_id     = var.tenancy_ocid
  compartment_id = var.compartment_ocid

  create_iam_resources         = true
  create_iam_tag_namespace = var.create_iam_tag_namespace
  create_iam_defined_tags  = var.create_iam_tag_namespace || var.create_iam_defined_tags
  use_defined_tags         = var.use_defined_tags
  tag_namespace            = var.tag_namespace
  create_iam_autoscaler_policy = "never"
  create_iam_wlsserver_policy     = var.create_iam_wlsserver_policy ? "always" : "never"

  #Network
  # Network
  create_vcn                  = var.create_vcn
  vcn_id                      = var.vcn_id
  vcn_cidrs                   = split(",", var.vcn_cidrs)
  vcn_create_internet_gateway = var.vcn_create_internet_gateway ? "always" : "never"
  vcn_create_nat_gateway      = var.vcn_create_nat_gateway ? "always" : "never"
  vcn_create_service_gateway  = var.vcn_create_service_gateway ? "always" : "never"
  vcn_name                    = var.vcn_name
  vcn_dns_label               = var.vcn_dns_label
  assign_dns                  = var.assign_dns
  ig_route_table_id           = var.ig_route_table_id
  local_peering_gateways      = var.local_peering_gateways
  lockdown_default_seclist    = var.lockdown_default_seclist
  create_drg                  = var.create_drg
  drg_id                      = var.drg_id
  drg_display_name            = var.drg_display_name

  subnets = {
    bastion = {
      create  = var.bastion_subnet_create ? "always" : "never",
      newbits = var.bastion_subnet_newbits,
      id      = var.bastion_subnet_id
    }

    #    operator = {
    #      create  = "never",  #future release
    #      newbits = var.operator_subnet_newbits,
    #      id      = var.operator_subnet_id
    #    }

    int_lb = {
      create  = var.int_lb_subnet_create ? "always" : "never",
      newbits = var.int_lb_subnet_newbits,
      id      = var.int_lb_subnet_id
    }

    pub_lb = {
      create  = var.pub_lb_subnet_create ? "always" : "never",
      newbits = var.pub_lb_subnet_newbits,
      id      = var.pub_lb_subnet_id
    }

    wlsservers = {
      create  = var.wlsserver_subnet_create ? "always" : "never",
      newbits = var.wlsserver_subnet_newbits,
      id      = var.wlsserver_subnet_id
    }

  }

  # Network Security
  nsgs = {
    bastion  = { create = var.create_nsgs ? "always" : "never" }
    #operator = { create = var.create_nsgs ? "always" : "never" }
    int_lb   = { create = var.create_nsgs ? "always" : "never" }
    pub_lb   = { create = var.create_nsgs ? "always" : "never" } #TODO: JOI - Future release include existing Public LB NSG.
    managedserver  = {
      create = var.create_nsgs ? "always" : "never",
      id = var.managedserver_nsg_id
    }
    adminserver  = {
      create = var.create_nsgs ? "always" : "never" ,
      id = var.adminserver_nsg_id
    }
  }

  #Network Security
  allow_node_port_access       = var.allow_node_port_access
  allow_wlsservers_ssh_access      = var.allow_wlsserver_ssh_access
  allow_wlsservers_internet_access = var.allow_wlsserver_internet_access
  enable_waf                   = var.enable_waf #TODO: JOI - Future release


  allow_rules_internal_lb      = var.allow_rules_internal_lb  #TODO: JOI - Future release include internal lb rules
  allow_rules_public_lb        = var.allow_rules_public_lb


  # SSH Access
  ssh_public_key   = local.ssh_public_key
  ssh_public_key_path = var.ssh_public_key_path


  #Weblogic Servers Images
  create_domain          = var.create_domain  #true
  wlsserver_pools=var.wlsserver_pools
  wlsserver_image_type       = lower(local.wlsserver_image_type)
  wlsserver_image_id         = local.wlsserver_image_id
  wlsserver_image_os         = var.wlsserver_image_os
  wlsserver_image_os_version = var.wlsserver_image_os_version

  #Weblogic Server Instance Details
  wlsserver_cloud_init       = local.wlsserver_cloud_init
  wlsserver_shape = {
    shape            = var.wlsserver_shape
    ocpus            = var.wlsserver_ocpus
    memory           = var.wlsserver_memory
    boot_volume_size = var.wlsserver_boot_volume_size
  }

  freeform_tags = {
    wlsservers = lookup(var.wlsserver_tags, "freeformTags", {})
  }

  defined_tags = {
    wlsservers = lookup(var.wlsserver_tags, "definedTags", {})
  }

  #Object Storage Archive Repository
  bucket_name = var.bucket_name
  restore_wls_archives = "all"
  await_node_readiness = "all"

  #Weblogic Domain Common  - LoadBalancer, labels
  add_load_balancer=  var.add_load_balancer


  lbs = {
    pub_lb = { create = var.add_load_balancer ? "always" : "never", id = var.existing_load_balancer_id , backends=var.custom_backends}
  }
  lb_shape = {
    pub_lb = { shape=var.load_balancer_shape, min = var.lb_min_bandwidth, max=var.lb_max_bandwidth}

  }

  #Bastion
  create_bastion = var.create_bastion
  bastion_shape = {
    shape            = var.bastion_shape_name,
    ocpus            = var.bastion_shape_ocpus,
    memory           = var.bastion_shape_memory,
    boot_volume_size = var.bastion_shape_boot
  }
  bastion_allowed_cidrs = var.bastion_allowed_cidrs
  bastion_is_public = var.bastion_is_public
  bastion_public_ip           = null           # Ignored when create_bastion = true
  bastion_availability_domain = var.bastion_availability_domain
  bastion_user = var.bastion_user
  bastion_image_os = var.bastion_image_os
  bastion_image_os_version = var.bastion_image_os_version
  bastion_image_type          = var.bastion_image_type     # platform/custom
  bastion_image_id = var.bastion_image_id
  bastion_upgrade = false
  #bastion_tags = var.bastion_tags

}