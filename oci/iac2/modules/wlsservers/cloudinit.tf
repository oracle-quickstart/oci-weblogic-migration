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
#  for_each = { # Skip generation for mode = virtual-node-pool
#    for k, v in local.enabled_wlsserver_pools : k => v
#    if lookup(v, "mode", var.wlsserver_pool_mode) != "virtual-node-pool"
#  }
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
          "disk1" : "/dev/oracleoci/oraclevdb",
          "disk2" : "/dev/oracleoci/oraclevdc",
          "disk3" : "/dev/oracleoci/oraclevdd",
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
        #          fs_setup: [
        #            {
        #              label :  "disk1-mw",
        #              filesystem : "xfs",
        #              device : "disk1",
        #              partition : 1,
        #            },
        #            {
        #              label : "disk2-jdk",
        #              filesystem : "xfs",
        #              device : "disk1",
        #              partition : 2
        #            },
        #            {
        #              label: "disk3-domain",
        #              filesystem : "xfs",
        #              device : "disk1",
        #              partition : 3
        #            }
        #          ]
        #          mounts = [
        #             [ "LABEL=disk1-mw, ${local.block_volume_mw_mountpath}, xfs, defaults,_netdev,nofail 0 2"],
        #             [ "LABEL=disk2-jdk,  ${local.block_volume_jdk_mountpath}, xfs, defaults,_netdev,nofail 0 2"],
        #             [ "LABEL=disk3-domain, ${local.block_volume_domain_mountpath}, xfs, defaults,_netdev,nofail 0 2"],
        #          ]
        mounts = [
          [ "/dev/oracleoci/oraclevdb", "${local.block_volume_mw_mountpath}", "xfs", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
          [ "/dev/oracleoci/oraclevdc",  "${local.block_volume_jdk_mountpath}", "xfs", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
          [ "/dev/oracleoci/oraclevdd", "${local.block_volume_domain_mountpath}", "xfs", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
        ]
        mounts_default_fields= [ "None", "None", "auto", "defaults,_netdev,nofail", "0", "2"]
        #           mount_default_fields: [~, ~, 'auto', 'defaults,nofail,x-systemd.requires=cloud-init.service', '0', '2']
        #
      })
      #        #             - [ LABEL=disk2-foo, /foo, xfs, "defaults,nofail,x-systemd.device-timeout=30"]
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

#  # Write extra Weblogic configuration to filesystem
#  dynamic "part" {
#    for_each = each.value.disable_default_cloud_init ? [] : [1]
#    content {
#      content_type = "text/cloud-config"
#      content = jsonencode({
#        write_files = [
#          {
#            content = var.apiserver_private_host
#            path    = "/etc/wls/wls-apiserver"
#          },
#          {
#            content  = var.cluster_ca_cert
#            encoding = "base64"
#            path     = "/etc/kubernetes/ca.crt"
#          },
#        ]
#      })
#      filename   = "50-wls-config.yml"
#      merge_type = local.default_cloud_init_merge_type
#    }
#  }

  # Weblogic startup initialization
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/cloudinit-wls-network.tpl", {
          ports = each.value.ports
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
      filename     = "65-user-change-id.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

  # Weblogic startup initialization
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/cloudinit-wls-restore.tpl", {
        temp_oss_mount_point = local.oss_mount_point
        bucket_name = var.bucket_name
        user = var.user
        group = var.group
        block_volume_domain_mountpath = local.block_volume_domain_mountpath
        block_volume_mw_mountpath = local.block_volume_mw_mountpath
        block_volume_jdk_mountpath = local.block_volume_jdk_mountpath
#        middleware_archive=format("%s-%s-weblogic_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
#        jdk_archive =format("%s-%s-java_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
#        domain_archive =format("%s-%s-domain_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
      })
      filename     = "70-wls-restore.sh"
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
