# Copyright (c) 2024, 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "oci_core_instance" "wlsservers" {
  for_each             = local.enabled_instances
  availability_domain  = element(each.value.availability_domains, 1)
  fault_domain         = try(each.value.placement_fds[0], null)
  compartment_id       = each.value.compartment_id
  display_name         = each.key
  preserve_boot_volume = false
  shape                = each.value.shape
  #TODO: JOI: enable pre-release
  #  defined_tags            = each.value.defined_tags
  #  freeform_tags           = each.value.freeform_tags
  extended_metadata       = each.value.extended_metadata
  capacity_reservation_id = each.value.capacity_reservation_id

  dynamic "shape_config" {
    for_each = length(regexall("Flex", each.value.shape)) > 0 ? [1] : []
    content {
      ocpus = each.value.ocpus
      memory_in_gbs = ( # If > 64GB memory/core, correct input to exactly 64GB memory/core
        (each.value.memory / each.value.ocpus) > 64 ? each.value.ocpus * 64 : each.value.memory
      )
    }
  }

  #TODO (joi) future version - launch_volume_attachments should be dynamic based on var.wls_archived_volumes
  #   dynamic "launch_volume_attachments" {
  #     for_each = length(var.wls_archived_volumes) > 0 ? var.wls_archived_volumes : {}
  #     content {
  #       type = "iscsi"
  #     device = each.value.device
  #    display_name = format("mw-%s-%s-%v",var.resource_name_prefix,each.key,var.state_id)
  #    is_agent_auto_iscsi_login_enabled=true
  #    launch_create_volume_details {
  #      volume_creation_type = "ATTRIBUTES"
  #      compartment_id = each.value.compartment_id
  #      display_name = format("%s-%s-%s-%v",each.value.display_name, var.resource_name_prefix,each.key,var.state_id)
  #      size_in_gbs = each.value.size
  #    }
  #     }
  #   }
  // Create and attach a volume
  launch_volume_attachments {
    type                              = "iscsi"
    device                            = "/dev/oracleoci/oraclevdb"
    display_name                      = format("mw-%s-%s-%v", var.resource_name_prefix, each.key, var.state_id)
    is_agent_auto_iscsi_login_enabled = true
    launch_create_volume_details {
      volume_creation_type = "ATTRIBUTES"
      compartment_id       = each.value.compartment_id
      display_name         = format("mwi-%s-%s-%v", var.resource_name_prefix, each.key, var.state_id)
      size_in_gbs          = local.block_volume_mw_size
    }
  }

  // Create and attach a volume
  launch_volume_attachments {
    type                              = "iscsi"
    device                            = "/dev/oracleoci/oraclevdc"
    display_name                      = format("jdk-%s-%s-%v", var.resource_name_prefix, each.key, var.state_id)
    is_agent_auto_iscsi_login_enabled = true
    launch_create_volume_details {
      volume_creation_type = "ATTRIBUTES"
      compartment_id       = each.value.compartment_id
      display_name         = format("jdki-%s-%s-%v", var.resource_name_prefix, each.key, var.state_id)
      size_in_gbs          = local.block_volume_jdk_size
    }
  }

  // Create and attach a volume
  launch_volume_attachments {
    type                              = "iscsi"
    device                            = "/dev/oracleoci/oraclevdd"
    is_agent_auto_iscsi_login_enabled = true
    display_name                      = format("domain-%s-%s-%v", var.resource_name_prefix, each.key, var.state_id)
    launch_create_volume_details {
      volume_creation_type = "ATTRIBUTES"
      compartment_id       = each.value.compartment_id
      display_name         = format("domain-%s-%s-%v", var.resource_name_prefix, each.key, var.state_id)
      size_in_gbs          = local.block_volume_domain_size
    }
  }
  #TODO: JOI makes this default to true.  Just to be on the safe side.
  preserve_data_volumes_created_at_launch = false

  dynamic "platform_config" {
    for_each = each.value.platform_config != null ? [1] : []
    content {
      type = lookup(
        # Attempt lookup against data source for the associated 'type' of configured wlsserver shape
        lookup(local.platform_config_by_shape, each.value.shape, {}), "type",
        # Fall back to 'type' on pool with custom platform_config, or INTEL_VM default
        lookup(each.value.platform_config, "type", "INTEL_VM")
      )
      # Remaining parameters as configured, validated by instance/instance config resource
      are_virtual_instructions_enabled               = lookup(each.value.platform_config, "are_virtual_instructions_enabled", null)
      is_access_control_service_enabled              = lookup(each.value.platform_config, "is_access_control_service_enabled", null)
      is_input_output_memory_management_unit_enabled = lookup(each.value.platform_config, "is_input_output_memory_management_unit_enabled", null)
      is_measured_boot_enabled                       = lookup(each.value.platform_config, "is_measured_boot_enabled", null)
      is_memory_encryption_enabled                   = lookup(each.value.platform_config, "is_memory_encryption_enabled", null)
      is_secure_boot_enabled                         = lookup(each.value.platform_config, "is_secure_boot_enabled", null)
      is_symmetric_multi_threading_enabled           = lookup(each.value.platform_config, "is_symmetric_multi_threading_enabled", null)
      is_trusted_platform_module_enabled             = lookup(each.value.platform_config, "is_trusted_platform_module_enabled", null)
      numa_nodes_per_socket                          = lookup(each.value.platform_config, "numa_nodes_per_socket", null)
      percentage_of_cores_enabled                    = lookup(each.value.platform_config, "percentage_of_cores_enabled", null)
    }
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false
    plugins_config {
      #Required
      desired_state = "ENABLED"
      name          = "Bastion"
    }
    plugins_config {
      #Required
      desired_state = "ENABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      name          = "OS Management Service Agent"
      desired_state = "DISABLED"
    }


  }

  create_vnic_details {
    assign_private_dns_record = var.assign_dns
    assign_public_ip          = each.value.assign_public_ip
    nsg_ids                   = each.value.nsg_ids
    subnet_id                 = each.value.subnet_id
    hostname_label            = each.value.hostname
    #TODO: JOI: enable pre-release
    #    defined_tags              = each.value.defined_tags
    #    freeform_tags             = each.value.freeform_tags
  }

  # Set to true to disable the legacy (/v1) Instance Metadata Service (IMDS) endpoints.
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  metadata = merge(
    {
      logs_dir                = "/var/log/owm"
      wls_domain_name         = var.resource_name_prefix
      vmscripts_path          = var.vm_scripts_path
      mode                    = var.mode
      wls-tenancy-id          = var.tenancy_id
      wls-initial-node-labels = join(",", [for k, v in each.value.node_labels : format("%v=%v", k, v)])
      is_admin_instance       = tostring(each.value.index == 0)
      secondary_vnics         = jsonencode(lookup(each.value, "secondary_vnics", {}))
      ssh_authorized_keys     = var.ssh_public_key
      user_data               = lookup(lookup(data.cloudinit_config.wlsservers, each.key, {}), "rendered", "")
      wlsserver_vcn_id        = var.wlsserver_vcn_id
      wlsserver_subnet_id     = var.wlsserver_subnet_id
      db_subnet_id            = var.db_subnet_id
      is_vcn_peering          = var.is_vcn_peering
      db_lpg                  = var.db_lpg
      wlsserver_lpg           = var.wlsserver_lpg
      create_db_ingress_sl    = var.create_db_ingress_sl
      db_security_list_id     = var.db_security_list_id
    },

    # Extra user-defined fields merged last
    var.node_metadata,                       # global
    lookup(each.value, "node_metadata", {}), # pool-specific
  )

  source_details {
    boot_volume_size_in_gbs = each.value.boot_volume_size
    source_id               = each.value.image_id
    source_type             = "image"
  }

  lifecycle {
    precondition {
      condition     = coalesce(each.value.image_id, "none") != "none"
      error_message = <<-EOT
      Missing image_id; check provided value if image_type is 'custom', or image_os/image_os_version if image_type is 'marketplace' or 'platform'.
        pool: ${each.key}
        image_type: ${coalesce(each.value.image_type, "none")}
        image_id: ${coalesce(each.value.image_id, "none")}
      EOT
    }

    ignore_changes = [
      defined_tags, freeform_tags, display_name,
      metadata["cluster_ca_cert"], metadata["user_data"],
      create_vnic_details[0].defined_tags,
      create_vnic_details[0].freeform_tags,
    ]
  }
}
