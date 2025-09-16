# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  update_wls_config_enabled = var.restore_wls_archives != "none" && var.await_node_readiness != "none" && var.expected_node_count > 0 && var.wls_domain_path !="none" && length(var.text_to_replace_in_config) > 0
  update_wls_config_script = "/home/${var.bastion_user}/update_weblogic_config.sh"
  update_config_commands = templatefile("${path.module}/resources/update_wls_config.tftpl", {
    oci_host_listen_address = var.text_to_replace_in_config

    domain_path = var.wls_domain_path
    user = var.user
  })
}

resource "null_resource" "update_wls_config" {
#  count = local.restore_enabled ? var.expected_node_count : 0
  for_each = local.update_wls_config_enabled ? var.wlsserver_pools : {} #local.restore_instances
  triggers = {
    update_config_commands = jsonencode(local.update_config_commands)
  }

  connection {
    agent       = true
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = var.ssh_private_key
    host                = each.value.private_ip
    user                = var.bastion_user
    private_key         = var.ssh_private_key
    timeout             = "40m"
    type                = "ssh"
  }

  provisioner "file" {
    content      = local.update_config_commands
    destination = local.update_wls_config_script
  }

  provisioner "remote-exec" {
    inline = ["bash ${local.update_wls_config_script}"]
  }

  depends_on = [null_resource.restore_wls_archives]
}
