# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl


#data "template_file" "managed_server_init_script" {
#  template = file("${path.module}/templates/cloudinit-wls.tpl")
#
#  vars = {
#    managed_server_ports = <<EOT
#    %{ for port in var.wlsserver_ports ~}
#      server ${port}
#    %{ endfor ~}
#    EOT
#    temp_oss_mount_point = local.oss_mount_point
#    bucket_name = var.bucket_name
#  }
#}
#
#data "template_file" "adminserver_init_script" {
#  template = file("${path.module}/templates/cloudinit-wls.tpl")
#
#  vars = {
#    managed_server_ports = <<EOT
#    %{ for port in var.adminserver_ports ~}
#      server ${port}
#    %{ endfor ~}
#    EOT
#    temp_oss_mount_point = local.oss_mount_point
#    bucket_name = var.bucket_name
#  }
#}
#

