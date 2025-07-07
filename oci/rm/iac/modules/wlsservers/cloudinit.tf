# Copyright (c) 2024, 2025 Oracle Corporation and/or its affiliates.
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


  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/cloud-config"
      # https://cloudinit.readthedocs.io/en/latest/reference/modules.html#users-and-groups
      content      = jsonencode({
        users = ["default",{
          "name":var.user,
          "uid": var.user_id,
        }
        ],

      })
      filename     = "20-user.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

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
          [ local.block_volume_mw_device_id, "${local.block_volume_mw_mountpath}", "ext4", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
          [ local.block_volume_jdk_device_id,  "${local.block_volume_jdk_mountpath}", "ext4", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
          [ local.block_volume_domain_device_id, "${local.block_volume_domain_mountpath}", "ext4", "defaults,_netdev,nofail,x-systemd.device-timeout=30s,x-systemd.makefs", "0","2"],
        ]
        mounts_default_fields= [ "None", "None", "auto", "defaults,_netdev,nofail", "0", "2"]
      })

      filename   = "40-disk-setup.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

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

  # Python scripts to restore file system
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/cloud-config"
      content = jsonencode({
        write_files = [
          {
            content = templatefile("${path.module}/templates/restore_archives.py", {
                    restore_path="/"
                    bucket_name=var.bucket_name
                    temporary_path=var.stage_archive_path
                    middleware_archive=format("%s-%s-weblogic_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
                    jdk_archive =format("%s-%s-java_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
                    domain_archive =format("%s-%s-domain_home.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
                    custom_archive =format("%s-%s-custom_dirs.tar.gz",each.value.wls_machine_name,var.resource_name_prefix)
            })
            path    = "/opt/scripts/restore_archives.py"
          },
        ]
      })
      filename   = "71-wls-restore-archives.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

   # Write Python files to perform database related task
   dynamic "part" {
     for_each = each.value.disable_default_cloud_init ? [] :  try(length(var.wls_datasources_config), 0) > 0 ? [1]:[]
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
           {
             content  = file("${path.module}/templates/vcn_peering.py")
             path     = "/opt/scripts/vcn_peering.py"
           },
           {
             content  = file("${path.module}/templates/atp_db_util.py")
             path     = "/opt/scripts/atp_db_util.py"
           },
         ]
       })
       filename   = "72-wls-ds-scripts.yml"
       merge_type = local.default_cloud_init_merge_type
     }
   }

  # Python script to restore OSVM Scripts If mode=dev download from OSS else use image vmscripts
#  dynamic "part" {
#    for_each = each.value.disable_default_cloud_init ? [] : [1]
#    content {
#      content_type = "text/cloud-config"
#      content = jsonencode({
#        write_files = [
#          {
#            content = templatefile("${path.module}/templates/restore-vmscripts.py", {
#              bucket_name=var.bucket_name
#              temporary_path="/tmp"
#              vmscripts_file=var.vm_scripts_path  #"wlsoci-vmscripts.zip"
#            })
#            path    = "/opt/scripts/restore-vmscripts.py"
#          },
#        ]
#      })
#      filename   = "73-wls-restore-vmscripts.yml"
#      merge_type = local.default_cloud_init_merge_type
#    }
#  }

  # VMscript bootstrap file
  dynamic "part" {
    #TODO vm_script_path bootstrap part should only be enabled if this is a devel environment.
    #     for_each = each.value.disable_default_cloud_init && var.is_development ? [] : [1]
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content = templatefile("${path.module}/templates/cloudinit-os-vmscripts.tpltf.sh", {
        user =var.user
        vmscripts_file=var.vm_scripts_path  #"wlsoci-vmscripts.zip"
      })
      filename   = "74-os-vmscripts.yml"
      merge_type = local.default_cloud_init_merge_type
    }
  }

  # Restore Bash bootstrap script to restore WLS Archives
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : [1]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/cloudinit-wls-restore-archives.tpl.sh", {
        user = var.user
        jdk_device_id =local.block_volume_jdk_device_id
        mw_device_id = local.block_volume_mw_device_id
        domain_device_id = local.block_volume_domain_device_id
        group = var.group
        block_volume_jdk_mountpath = local.block_volume_jdk_mountpath
        block_volume_domain_mountpath = local.block_volume_domain_mountpath
        block_volume_mw_mountpath = local.block_volume_mw_mountpath
        java_path = var.wls_data["resources"]["Machines"][each.value.wls_machine_name]["JavaPath"]
        canonical_java_path = var.wls_data["resources"]["Machines"][each.value.wls_machine_name]["CanonicalJavaPath"]
      })
      filename     = "79-wls-restore-archives.sh"
      merge_type   = local.default_cloud_init_merge_type
    }
  }



  # WLS config updates. 8x-filename.sh or .yml

  # Update Datasources
  dynamic "part" {
    for_each = each.value.disable_default_cloud_init ? [] : try(length(var.wls_datasources_config), 0) > 0 ?[1]:[]
    content {
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/cloudinit-wls-update-jdbc-datasources.tpl.sh", {
        user = var.user
        domain_home = var.wls_domain_home
        datasources = coalesce(var.wls_datasources_config, {})
      })
      filename     = "80-wls-update_datasources.sh"
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
      filename     = "81-wls-update_config_w_new_env.sh"
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
