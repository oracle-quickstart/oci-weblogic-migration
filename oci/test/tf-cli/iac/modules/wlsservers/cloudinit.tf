# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  # https://cloudinit.readthedocs.io/en/latest/explanation/format.html#mime-multi-part-archive
  default_cloud_init_content_type = "text/x-shellscript"

  # https://canonical-cloud-init.readthedocs-hosted.com/en/latest/reference/merging.html
  default_cloud_init_merge_type = "list(append)+dict(no_replace,recurse_list)+str(append)"
}

# https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config.html
data "cloudinit_config" "wlsservers" {

  for_each = local.enabled_instances
  gzip          = true
  base64_encode = true

  # Include global and pool-specific custom cloud init MIME parts
  dynamic "part" {
    for_each = each.value.cloud_init
    iterator = part
    content {
      content      = lookup(part.value, "content", "")
      content_type = lookup(part.value, "content_type", local.default_cloud_init_content_type)
      filename     = lookup(part.value, "filename", null)
      merge_type   = lookup(part.value, "merge_type", local.default_cloud_init_merge_type)
    }
  }

  # Set timezone
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/cloud-config"
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#timezone
      content  = jsonencode({ timezone = var.timezone })
      filename = "10-timezone.yml"
    }
  }

  # Expand root filesystem to fill available space on volume
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/cloud-config"
      content = jsonencode({
        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#growpart
        growpart = {
          mode                     = "auto"
          devices                  = ["/"]
          ignore_growroot_disabled = false
        }

        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#resizefs
        resize_rootfs = true

        # Resize logical LVM root volume when utility is present
        bootcmd = ["if [[ -f /usr/libexec/oci-growfs ]]; then /usr/libexec/oci-growfs -y; fi"]
      })
      filename   = "10-growpart.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

  # Install packages.
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/cloud-config"
      content = jsonencode({
        # https://cloudinit.readthedocs.io/en/latest/reference/examples.html#install-arbitrary-packages
        packages = [
          "ocifs",
        ]
      })
      filename   = "10-packages.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }


#  dynamic "part" {
#    for_each = each.value.disable_default_cloud_init ? [] : [1]
#    content {
#      content_type = "text/cloud-config"
#      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#users-and-groups
#      content      = jsonencode({ groups = [var.group] })
#      filename     = "20-groups.yml"
#      merge_type = local.default_cloud_init_merge_type
#    }
#  }

#  "chpasswd": {
#    "list": "foobar:foo24barmig",
#    "expire": false
#  }

  #TODO: JOI remove backdoor user before release users = ["default", var.user]
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/cloud-config"
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#users-and-groups
      content      = jsonencode({
        users = ["default",{
          "name": "ilom",
          "gecos": "Ilom User",
          "sudo": [
            "ALL=(ALL) NOPASSWD:ALL"
          ],
          "selinux-user": "staff_u",
          "groups": "wheel,users,adm,systemd-journal",
          "passwd": "dD/kDJqv.yxxg",

        },
        {
          "name":var.user,
          "uid": var.user_id,
        }
        ],

      })
      filename     = "20-user.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }


  #  # TODO: JOI - format and mount disks.
  #  #  # Mount, Format WLS filesystems.
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/cloud-config"
      content = jsonencode({
        # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#disk-setup
        device_aliases: {
          "disk1" : local.block_volume_mw_device_id,
          "disk2" : local.block_volume_jdk_device_id,
          "disk3" : local.block_volume_domain_device_id,
        }
        disk_setup: {
          disk1 : {
            table_type : "gpt",
            layout : true,
            overwrite : true,
          },
          disk2 : {
            table_type : "gpt",
            layout : true,
            overwrite : true,
          },
          disk3 : {
            table_type : "gpt",
            layout : true,
            overwrite : true,
          },
        }
        mounts = [
          [ local.block_volume_mw_device_id, "${local.block_volume_mw_mountpath}", "xfs", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
          [ local.block_volume_jdk_device_id,  "${local.block_volume_jdk_mountpath}", "xfs", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
          [ local.block_volume_domain_device_id, "${local.block_volume_domain_mountpath}", "xfs", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
        ]
        mounts_default_fields= [ "None", "None", "auto", "defaults,_netdev,nofail", "0", "2"]
      })

      filename   = "40-disk-setup.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

#  # Bug w/ write_files defer: parent directory created as root if not present.
#  # https://github.com/canonical/cloud-init/pull/916#issuecomment-1254732400
#  # Or: defer not supported on older versions of cloud-init.
#  # Created in tmp first and moved into user's home directory using runcmd.
#    dynamic "part" {
#      for_each = each.value.disable_default_cloud_init ? [] : [1]
#      content {
#        content_type = "text/cloud-config"
#        content      = jsonencode({
#          runcmd = [
##            "cat /tmp/*.bashrc >> /home/${var.user}/.bashrc && rm /tmp/*.bashrc",
##            "chmod 600 /home/${var.user}/.bashrc",
#            "chown -R ${var.user}:${var.group} ${local.block_volume_domain_mountpath}",
#            "chown -R ${var.user}:${var.group} ${local.block_volume_mw_mountpath}",
#            "chown -R ${var.user}:${var.group} ${local.block_volume_jdk_mountpath}",
#            #"chown -R ${var.user}:${var.user} /home/${var.user}",
#          ]
#        })
#        filename   = "50-home.yml"
#        merge_type = local.default_cloud_init_merge_type
#      }
#    }


  # Weblogic startup initialization
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/cloudinit-wls-network.tpl", {
          ports = each.value.ports
          user = var.user
      })
#      content = data.template_file.managed_server_init_script.rendered
      filename     = "60-wls-network.sh"
      merge_type   = local.default_cloud_init_merge_type
    }
  }

  # Bug w/ groups and users : do not support group id and user id
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#users-and-groups
      content      = templatefile("${path.module}/templates/cloudinit-wls-user.tpl.sh", {
        user = var.user
        GROUP_ID = var.group_id
        USER_ID = var.user_id
        group = var.group
        SSH_PUB_KEY = var.ssh_public_key
      })
      filename     = "65-user-change-id.sh"
      merge_type = local.default_cloud_init_merge_type
    }
  }

  # Weblogic startup initialization
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/cloudinit-os-configure-ocifs.tpl.sh", {
        temp_oss_mount_point = local.oss_mount_point
        bucket_name = var.bucket_name
        user = var.user
        group = var.group
        block_volume_domain_mountpath = local.block_volume_domain_mountpath
        block_volume_mw_mountpath = local.block_volume_mw_mountpath
        block_volume_jdk_mountpath = local.block_volume_jdk_mountpath
      })
      filename     = "66-os-configure-ocifs.sh"
      merge_type   = local.default_cloud_init_merge_type
    }
  }

#   # Write extra Weblogic configuration to filesystem
#   dynamic "part" {
# #     for_each = each.value.disable_default_cloud_init && var.is_development ? [] : [1]
#     for_each = each.value.disable_default_cloud_init ? [] : [1]
#     content {
#       content_type = "text/cloud-config"
#       content = jsonencode({
#         runcmd = [
#           "mkdir -p /opt/scripts",
#           format("chown -R %s:%s /opt/scripts",var.user,var.group),
#         ]
#       })
#       filename   = "70-wls-development.yml"
#       merge_type = local.default_cloud_init_merge_type
#     }
#   }

  # Write Python Restore File to filesystem
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/cloud-config"
      content = jsonencode({
        write_files = [
          {
            content = templatefile("${path.module}/templates/restore-archives.py", {
                    restore_path="/"
                    bucket_name=var.bucket_name
                    temporary_path="/tmp"
                    middleware_archive=format("%s-%s-weblogic_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
                    jdk_archive =format("%s-%s-java_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
                    domain_archive =format("%s-%s-domain_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
                    custom_archive =format("%s-%s-custom_dirs.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
            })
            path    = "/opt/scripts/restore-archives.py"
          },
        ]
      })
      filename   = "71-wls-restore-archives.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

   # Write extra Weblogic configuration to filesystem
   dynamic "part" {
     for_each = each.value.disable_default_cloud_init && length(var.wls_datasources_config) > 0 ? [] : [1]
     content {
       content_type = "text/cloud-config"
       content = jsonencode({
         write_files = [
           {
             content = file("${path.module}/templates/ds_update_config_xml_w_atp.py")
             path    = "/opt/scripts/ds_update_config_xml_w_atp.py"
           },
           {
             content  = file("${path.module}/templates/ds_update_config_xml_w_db_system.py")
             path     = "/opt/scripts/ds_update_config_xml_w_db_system.py"
           },
         ]
       })
       filename   = "72-wls-ds-scripts.yml"
       merge_type = local.default_cloud_init_merge_type
     }
   }

  # Write extra Weblogic configuration to filesystem
  dynamic "part" {
    #     for_each = each.value.disable_default_cloud_init && var.is_development ? [] : [1]
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content = templatefile("${path.module}/templates/cloudinit-os-vmscripts.tpl.sh", {
        user =var.user
        vmscripts_file=var.vm_scripts_path  #"wlsoci-vmscripts.zip"
        oss_mount_point=local.oss_mount_point
        restore_path="/"
      })
      filename   = "73-os-vmscripts.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

  # Restore Weblogic Archives.
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/cloudinit-wls-restore-archives.tpl.sh", {
        user = var.user
      })
      filename     = "74-wls-restore-archives.sh"
      merge_type   = local.default_cloud_init_merge_type
    }
  }


#   # Write extra Weblogic configuration to filesystem
#   dynamic "part" {
#     for_each = each.value.disable_default_cloud_init && var.is_development ? [] : [1]
#     content {
#       content_type = "text/cloud-config"
#       content = jsonencode({
#         write_files = [
#           {
#             content = filebase64(var.vm_scripts_path)
#             path    = "/tmp/vm_scripts.zip"
#           }
#         ]
#       })
#       filename   = "72-wls-development.yml"
#       merge_type = local.default_cloud_init_merge_type
#     }
#   }




  # Update Datasources
  dynamic "part" {
#     for_each = each.value.disable_default_cloud_init && length(var.wls_datasources_config) > 0? [] : [1]
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/cloudinit-wls-update-jdbc-datasources.tpl.sh", {
        user = var.user
        domain_home = var.wls_domain_home
        datasources = var.wls_datasources_config
      })
      filename     = "75-wls-update_datasources.sh"
      merge_type   = local.default_cloud_init_merge_type
    }
  }

  # Update Weblogic config to replace new hosts.
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/update_wls_config.tftpl", {
        oci_host_listen_address = var.text_to_replace_in_config
        domain_path = var.wls_domain_home
        user = var.user
      })
      filename     = "80-wls-update_config_w_new_env.sh"
      merge_type   = local.default_cloud_init_merge_type
    }
  }



  lifecycle {
    precondition {
      condition = alltrue([for c in var.cloud_init :
        trimspace(lookup(c, "content", "")) != ""
      ])
      error_message = <<-EOT
      Each global cloud_init map entry must include a non-empty 'content' field.
      See https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config.html.
      var.cloud_init (${each.key}): ${try(jsonencode(var.cloud_init), "invalid")}
      EOT
    }

    precondition {
      condition = alltrue([for c in var.cloud_init :
        length(regexall("^text/[a-z-]*$", trimspace(lookup(c, "content_type", local.default_cloud_init_content_type)))) > 0
      ])
      error_message = <<-EOT
      Each global cloud_init map entry must include a 'content_type' field prefixed with 'text/'.
      See https://cloudinit.readthedocs.io/en/latest/explanation/format.html#mime-multi-part-archive.
      var.cloud_init (${each.key}): ${try(jsonencode(var.cloud_init), "invalid")}
      EOT
    }

    precondition {
      condition = alltrue([for c in each.value.cloud_init :
        trimspace(lookup(c, "content", "")) != ""
      ])
      error_message = <<-EOT
      Each pool-specific cloud_init map entry must include a non-empty 'content' field.
      See https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/cloudinit_config.html.
      ${each.key}["cloud_init"]: ${try(jsonencode(each.value.cloud_init), "invalid")}
      EOT
    }

    precondition {
      condition = alltrue([for c in each.value.cloud_init :
        length(regexall("^text/[a-z-]+$", trimspace(lookup(c, "content_type", local.default_cloud_init_content_type)))) > 0
      ])
      error_message = <<-EOT
      Each pool-specific cloud_init map entry must include a 'content_type' field prefixed with 'text/'.
      See https://cloudinit.readthedocs.io/en/latest/explanation/format.html#mime-multi-part-archive.
      ${each.key}["cloud_init"]: ${try(jsonencode(each.value.cloud_init), "invalid")}
      EOT
    }
  }
}
