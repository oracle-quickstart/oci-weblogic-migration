# Copyright (c) 2028 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  restore_enabled = var.restore_wls_archives != "none" && var.await_node_readiness != "none" && var.expected_node_count > 0
  restore_instances = (local.restore_enabled
    ? tolist([for k, v in var.wlsserver_pools : k if tobool(lookup(v, "restore", false))]) : []
  )
  oss_mount_point =  format("/home/%s/oss",var.user)
  restore_archives_script = "/home/${var.bastion_user}/restore_archives.sh"

#TODO: JOI: remove comment before release.

#  restore_commands = formatlist(
#    format(
#      "kubectl drain %v %v %v %v",
#      format("--timeout=%vs", var.worker_drain_timeout_seconds),
#      format("--ignore-daemonsets=%v", var.worker_drain_ignore_daemonsets),
#      format("--delete-emptydir-data=%v", var.worker_drain_delete_local_data),
#      "-l oke.oraclecloud.com/pool.name=%v" # interpolation deferred to formatlist
#    ),
#    local.restore_instances
#  )


}

resource "null_resource" "restore_wls_archives" {
#  count = local.restore_enabled ? var.expected_node_count : 0
  for_each = local.restore_enabled ? var.wlsserver_pools : {} #local.restore_instances
#  triggers = {
#    restore_instances    = jsonencode(sort(local.restore_instances))
##    restore_commands = jsonencode(local.restore_commands)
#  }

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
    content      = templatefile("${path.module}/resources/node-wls-restore.tpl", {
      temp_oss_mount_point = local.oss_mount_point
      middleware_archive=format("%s-%s-weblogic_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
      jdk_archive =format("%s-%s-java_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
      domain_archive =format("%s-%s-domain_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
    })
    destination = local.restore_archives_script
  }

  provisioner "remote-exec" {
    inline = ["bash ${local.restore_archives_script}"]
  }

  depends_on = [null_resource.await_node_readiness]
}


#resource "null_resource" "status_check" {
#  count      = var.assign_public_ip || var.is_bastion_instance_required || var.is_rms_private_endpoint_required ? var.num_vm_instances : 0
#  depends_on = [null_resource.dev_mode_provisioning]
#
#  // Connection setup for all WLS instances
#  connection {
#    agent       = false
#    timeout     = "30m"
#    host        = var.is_rms_private_endpoint_required ? data.oci_resourcemanager_private_endpoint_reachable_ip.private_endpoint_reachable_ips[count.index].ip_address : var.host_ips[count.index]
#    user        = "opc"
#    private_key = var.ssh_private_key
#
#    bastion_user        = "opc"
#    bastion_private_key = var.is_rms_private_endpoint_required ? "" : var.bastion_host_private_key
#    bastion_host        = var.is_rms_private_endpoint_required ? "" : var.bastion_host
#  }
#
#  // Call check_status.sh 11 more times - if we add additional markers we must add an additional status check call here.
#  // Also see - all_markers_list in check_provisioning_status.py for the list of all existing markers.
#  // It is OK to call provisioning check more times than there are markers but we should at least call it as many times
#  // as there are number of marker files created on VM.
#
#  provisioner "remote-exec" {
#    inline = [
#      "sudo sh /opt/scripts/check_status.sh",
#      "sudo su - oracle -c 'python3 /opt/scripts/check_provisioning_status.py'",
#    ]
#  }