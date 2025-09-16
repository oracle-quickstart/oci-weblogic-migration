# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  node_ready_script = "/home/${var.bastion_user}/await_node_ready.sh"
  node_ready_template = templatefile("${path.module}/resources/await_node_readiness.tpl",
    {
      await_node_readiness = var.await_node_readiness
      expected_node_count  = var.expected_node_count
    }
  )
}
# for_each = { for k in compact([for k, v in var.mymap: v.condition ? k : ""]): k => var.mymap[k] }
resource "null_resource" "await_node_readiness" {
  for_each = var.await_node_readiness != "none" && var.expected_node_count > 0 ? var.wlsserver_pools : {}
#  count    = var.await_node_readiness != "none" && var.expected_node_count > 0 ? 1 : 0
  triggers = { expected_node_count = var.expected_node_count }

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
    content     = local.node_ready_template
    destination = local.node_ready_script
  }

  provisioner "remote-exec" {
    inline = ["bash ${local.node_ready_script}"]
  }

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait &> /dev/null"]
  }
}
