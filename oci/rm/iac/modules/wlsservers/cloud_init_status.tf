# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "null_resource" "await_cloudinit" {
  for_each = oci_core_instance.wlsservers

  depends_on = [oci_core_instance.wlsservers]

  connection {
    type        = "ssh"
    user        = "opc"
    timeout     = "30m"
    private_key = var.opc_key["private_key_pem"]
    host        = var.create_bastion ? each.value.private_ip : data.oci_resourcemanager_private_endpoint_reachable_ip.private_endpoint_reachable_ips[each.key].ip_address

    bastion_host        = var.bastion_host_ip
    bastion_user        = "opc"
    bastion_private_key = var.bastion_host_private_key
  }

  provisioner "remote-exec" {
    script = "${path.module}/templates/cloudinit-check.sh"
  }
}
