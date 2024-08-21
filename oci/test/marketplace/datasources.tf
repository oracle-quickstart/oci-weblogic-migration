# Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

# Available OCI Services
data "oci_core_services" "all_services_network" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# Latest Image for CPE Compute Instance
data "oci_core_images" "cpe_compute_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.cpe_image_operating_system
  operating_system_version = var.cpe_image_operating_system_version
  shape                    = var.mp_instance_shape.instanceShape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}


## Latest Image for Example LDAP Compute Instance
#data "oci_core_images" "ldap_compute_images" {
#  compartment_id           = var.compartment_id
#  operating_system         = var.ldap_image_operating_system
#  operating_system_version = var.ldap_image_operating_system_version
#  shape                    = var.ldap_instance_shape.instanceShape
#  sort_by                  = "TIMECREATED"
#  sort_order               = "DESC"
#}


# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

## Private IP for CPE
#data "oci_core_private_ips" "cpe" {
#  ip_address = oci_core_instance.mp_instance.0.private_ip
#  subnet_id = var.create_subnets ? module.subnets["test_subnet"].subnet_id : var.existent_test_subnet_ocid
#}

### OCI VCN DS
#data "oci_core_vcn" "existent_oci_vcn" {
#  vcn_id = var.existent_oci_vcn_ocid
#}

# Check for resource limits
## Check available compute shape
data "oci_limits_services" "compute_services" {
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = ["compute"]
  }
}
#data "oci_limits_limit_definitions" "compute_limit_definitions" {
#  compartment_id = var.tenancy_ocid
#  service_name   = data.oci_limits_services.compute_services.services.0.name
#
#  filter {
#    name   = "description"
#    values = [local.compute_shape_description]
#  }
#}
