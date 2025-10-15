# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

data "oci_identity_fault_domains" "all" {
  for_each            = var.ad_numbers_to_names
  availability_domain = each.value
  compartment_id      = var.compartment_id
}

data "oci_resourcemanager_private_endpoint_reachable_ip" "private_endpoint_reachable_ips" {
  for_each            = var.create_bastion ? {} : oci_core_instance.wlsservers
  private_endpoint_id = var.rms_private_endpoint_id
  private_ip          = each.value.private_ip
}

data "template_file" "key_script" {
  template = file("${path.module}/../bastion/templates/keys.tpl")

  vars = {
    pubKey = var.opc_key["public_key_openssh"]
  }
}