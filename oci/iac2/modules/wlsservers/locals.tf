# Copyright (c) 2022, 2023 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  oss_mount_point =  format("/home/%s/oss",var.user)
  boot_volume_size = lookup(var.shape, "boot_volume_size", 50)
  memory           = lookup(var.shape, "memory", 4)
  ocpus            = max(1, lookup(var.shape, "ocpus", 1))
  shape            = lookup(var.shape, "shape", "VM.Standard.E4.Flex")
  # TODO:  JOI: move sizes and file system to a map(any)
  block_volume_mw_size = 251
  block_volume_jdk_size = 102
  block_volume_domain_size = 253
  block_volume_data_size = 254
  #  TODO: JOI: retrieve parent folder of each path provided. Example.  /opt/domains/testdomain mount point should be /opt/domains
  #"DomainPath" : "/opt/domains/testdomain",
  #  TODO: JOI:  Oracle Middelware will remain the same.  Unzipping contents will be only from directory to directory.
  #"OraclePath" : "/opt/middleware"

  block_volume_domain_mountpath = "/opt/domains"
  block_volume_mw_mountpath = "/opt/middleware"
  block_volume_jdk_mountpath="/opt/jdk"


  block_storage_devices_defaults = [
     {
      name = "middleware"
      size = local.block_volume_mw_size
    },
    {
      name = "jdk"
      size = local.block_volume_jdk_size
    },
    {
      name = "domain"
      size = local.block_volume_domain_size
    },
    {
    name ="data"
      size = local.block_volume_data_size
    }
  ]


  # Used for default values of required input for virtual node pools
  fault_domains_all = formatlist("FD-%v", [1, 2, 3])
  fault_domains_available = {
    for ad, fd in data.oci_identity_fault_domains.all : ad => fd
  }

  wlsserver_pool_defaults = {
    allow_autoscaler           = false
    assign_public_ip           = var.assign_public_ip
    autoscale                  = false
    block_volume_type          = var.block_volume_type
    boot_volume_size           = local.boot_volume_size
    block_storage_devices      = local.block_storage_devices_defaults
    capacity_reservation_id    = var.capacity_reservation_id
    cloud_init                 = [] # empty pool-specific default
    compartment_id             = var.compartment_id
    create                     = true
    disable_default_cloud_init = var.disable_default_cloud_init
    drain                      = false
    eviction_grace_duration    = 0
    force_node_delete          = true
    extended_metadata          = {} # empty pool-specific default
    image_id                   = var.image_id
    image_type                 = var.image_type
    memory                     = local.memory
    mode                       = var.wlsserver_pool_mode
    node_labels                = var.node_labels
    nsg_ids                    = { managedserver = var.managedserver_nsg_ids, adminserver=var.adminserver_nsg_ids, both=compact(concat(var.managedserver_nsg_ids,var.adminserver_nsg_ids)) }
    ocpus                      = local.ocpus
    os                         = var.image_os
    os_version                 = var.image_os_version
    placement_ads              = var.ad_numbers
    platform_config            = var.platform_config
    pv_transit_encryption      = var.pv_transit_encryption
    shape                      = local.shape
    size                       = var.wlsserver_pool_size
    subnet_id                  = var.wlsserver_subnet_id
    taints                     = [] # empty pool-specific default
    volume_kms_key_id          = var.volume_kms_key_id
    ports                      = { managedserver = var.wlsserver_ports, adminserver=var.adminserver_ports, both=compact(concat(var.wlsserver_ports,var.adminserver_ports)) }
  }

  # Merge desired pool configuration onto default values
  wlsserver_pools_with_defaults = { for pool_name, pool in var.wlsserver_pools :
  pool_name => merge(local.wlsserver_pool_defaults, pool)
  }

#  # Filter wlsserver_pools map for enabled entries and add derived configuration
  enabled_wlsserver_pools = { for pool_name, pool in local.wlsserver_pools_with_defaults :
    pool_name => merge(pool, {
      # Bare metal instances must use iSCSI block volume attachments, not paravirtualized
      block_volume_type = length(regexall("^BM", pool.shape)) > 0 ? "iscsi" : var.block_volume_type
      pv_transit_encryption = alltrue([
        var.pv_transit_encryption,
        pool.block_volume_type == "paravirtualized",
        length(regexall("^VM", pool.shape)) > 0
      ])

      # Combine global and pool-specific cloud init parts
      cloud_init = [for part in concat(var.cloud_init, pool.cloud_init) :
        {
          # Load content from file if local path, attempt base64 decode, or use raw value
          content = contains(keys(part), "content") ? (
            try(fileexists(lookup(part, "content")), false) ? file(lookup(part, "content"))
            : try(base64decode(lookup(part, "content")), lookup(part, "content"))
          ) : ""
          content_type = lookup(part, "content_type", local.default_cloud_init_content_type)
          filename     = lookup(part, "filename", null)
          merge_type   = lookup(part, "merge_type", local.default_cloud_init_merge_type)
        }
      ]

      # Translate configured + available AD numbers e.g. 2 into tenancy/compartment-specific names
      availability_domains = compact([for ad_number in tolist(setintersection(pool.placement_ads, var.ad_numbers)) :
        lookup(var.ad_numbers_to_names, ad_number, null)
      ])

      # TODO: JOI include marketplace images in image_id
      # Use provided image_id for 'custom' type, or first match for all shape + OS criteria
      image_id = (pool.image_type == "custom" ? pool.image_id : element(tolist(setintersection([
        lookup(var.image_ids, pool.image_type, null),
        length(regexall("GPU", pool.shape)) > 0 ? var.image_ids.gpu : var.image_ids.nongpu,
        length(regexall("A1", pool.shape)) > 0 ? var.image_ids.aarch64 : var.image_ids.x86_64,
        lookup(var.image_ids, format("%v %v", pool.os, split(".", pool.os_version)[0]), null),
      ]...)), 0))

      # Standard tags as defined if enabled for use
      # User-provided freeform tags are merged and take precedence
      defined_tags = merge(
        var.use_defined_tags ? merge(
          {
            "${var.tag_namespace}.state_id"           = var.state_id,
            "${var.tag_namespace}.role"               = "wlsserver",
            "${var.tag_namespace}.domain"               = var.resource_name_prefix,
#            "${var.tag_namespace}.pool"               = pool_name,
            #TODO:  JOI - add type = managedserver or adminserver
            #"${var.tag_namespace}.type"               = if (adminserver) ? adminserver: managedserver,

          },
        ) : {},
        var.defined_tags,
        lookup(pool, "defined_tags", {})
      )

      # Standard tags as freeform if defined tags are disabled
      # User-provided freeform tags are merged and take precedence
      freeform_tags = merge(
        var.use_defined_tags ? {} : merge(
          {
            "state_id"           = var.state_id,
            "role"               = "wlsserver",
            "domain"               = var.resource_name_prefix,
            #TODO:  JOI - add type = managedserver or adminserver
            #"type"               = if (adminserver) ? adminserver: managedserver,
          }
        ),
        var.freeform_tags,
        lookup(pool, "freeform_tags", {})
      )

#      #TODO:  JOI - nsg_ids = managedserver or adminserver or both ?
#      # Combine global and pool-specific NSGs
#      nsg_ids      = compact(concat(var.wlsserver_nsg_ids, pool.nsg_ids))
#      adminserver_nsg_ids = compact(concat(var.adminserver_nsg_ids, pool.adminserver_nsg_ids))


    }) if tobool(pool.create)
  }

  # modes = instance or instance-pool.  Future version instance-pool
  enabled_modes = distinct([for w in values(local.enabled_wlsserver_pools) : w.mode])

  # Number of nodes expected from enabled wlsserver pools
  expected_node_count = length(local.enabled_wlsserver_pools) == 0 ? 0 : sum([
    for k, v in local.enabled_wlsserver_pools : lookup(v, "size", var.wlsserver_pool_size)
  ])

#  # Number of nodes expected to be draining in wlsserver pools
#  expected_drain_count = length(local.enabled_wlsserver_pools) == 0 ? 0 : sum([
#    for k, v in local.enabled_wlsserver_pools : tobool(v.drain) ? lookup(v, "size", var.wlsserver_pool_size) : 0
#  ])

#  # Enabled wlsserver_pool map entries for node pools
#  enabled_node_pools = {
#    for k, v in local.enabled_wlsserver_pools : k => v
#    if lookup(v, "mode", "") == "node-pool"
#  }

#  # Enabled wlsserver_pool map entries for virtual node pools
#  enabled_virtual_node_pools = {
#    for k, v in local.enabled_wlsserver_pools : k => v
#    if lookup(v, "mode", "") == "virtual-node-pool"
#  }

#  # Enabled wlsserver_pool map entries for instance pools
#  enabled_instance_configs = {
#    for k, v in local.enabled_wlsserver_pools : k => v
#    if contains(["cluster-network", "instance-pool"], lookup(v, "mode", ""))
#  }

#  # Enabled wlsserver_pool map entries for instance pools
#  enabled_instance_pools = {
#    for k, v in local.enabled_wlsserver_pools : k => v if lookup(v, "mode", "") == "instance-pool"
#  }

  # Enabled wlsserver_pool map entries for individual instances
  enabled_instances = { for e in concat([], [
    for k, v in local.enabled_wlsserver_pools : [
      for i in range(0, lookup(v, "size", 0)) : merge(v, {
          "key" = k, "index" = i ,
          "hostname"=v.host_details[i].hostlabel ,   # check attribute host_details by key index and get hostlabel value
          "nsg_ids"=lookup(v.nsg_ids,v.host_details[i].host_type),  # lookup in pool defaults nsg_ids by host_type [index] and set admin,managed,or both nsgs
          "wls_machine_name"=v.host_details[i].wls_machine_name,  # get host_details by index and get machine name as discovered by wls inventory file
          "ports"=lookup(v.ports,v.host_details[i].host_type)}) # lookup in pool defaults ports by host_type [index] and set admin,managed,or both list of ports
    ] if lookup(v, "mode", "") == "instance"
  ]...) : format("%v-%v", lookup(e, "key"), lookup(e, "index")) => e }

#  # Enabled wlsserver_pool map entries for cluster networks
#  enabled_domain_networks = {
#    for k, v in local.enabled_wlsserver_pools : k => v if lookup(v, "mode", "") == "cluster-network"
#  }

  # Sanitized wlsserver_pools output; some conditionally-used defaults would be misleading
  wlsserver_pools_final = {
    for pool_name, pool in local.enabled_wlsserver_pools : pool_name => { for a, b in pool : a => b
      if a != "create"                                                                    # implied
      && b != null && try(length(b), -1) != 0 && try(!!tobool(b), true)                   # exclude empty/disabled values
      && !(contains(["os", "os_version"], a) && pool.image_type == "custom")              # unused defaults for custom
      && !(contains(["ocpus", "memory"], a) && length(regexall("Flex", pool.shape)) == 0) # unused defaults for non-Flex shapes
      #TODO: include marketplace
    }
  }

  # Maps of wlsserver pool OCI resources by pool name enriched with desired/custom parameters for various modes
#  wlsserver_node_pools         = { for k, v in oci_containerengine_node_pool.wlsservers : k => merge(v, lookup(local.wlsserver_pools_final, k, {})) }
#  wlsserver_virtual_node_pools = { for k, v in oci_containerengine_virtual_node_pool.wlsservers : k => merge(v, lookup(local.wlsserver_pools_final, k, {})) }
#  wlsserver_instance_pools     = { for k, v in oci_core_instance_pool.wlsservers : k => merge(v, lookup(local.wlsserver_pools_final, k, {})) }
#  wlsserver_cluster_networks   = { for k, v in oci_core_cluster_network.wlsservers : k => merge(v, lookup(local.wlsserver_pools_final, k, {})) }
  wlsserver_instances          = { for k, v in oci_core_instance.wlsservers : k => merge(v, lookup(local.wlsserver_pools_final, k, {})) }


#  wlsserver_instances = [for k, v in oci_core_instance.wlsservers :  ]

#  # Combined map of outputs by pool name for all modes excluding 'instance' (output separately)
#  wlsserver_pools_output = merge(
#    local.wlsserver_node_pools,
#    local.wlsserver_virtual_node_pools,
#    local.wlsserver_instance_pools,
#    local.wlsserver_cluster_networks,
#  )

#  # OCIDs of pool resources by pool name for modes: 'node-pool', 'virtual-node-pool', 'instance-pool', 'cluster-network'
#  wlsserver_pool_ids = { for k, v in local.wlsserver_pools_output : k => v.id }

  # TODO: JOI: DO NOT MODIFY.. USED OUTSIDE
  # Map of pool name to list of instance IP addresses for modes: 'instance'
  wlsserver_instance_ips = {
    for x, y in {
      for k, v in local.wlsserver_instances : replace(k, "/-[^-]*$/", "") => # remove index suffix
      { lookup(v, "id", "") = lookup(v, "private_ip", null) }...          # instances grouped by "pool"
    } : x => merge(y...)
  }

  # Map of pool name to list of changes on discovered instance vs oci_core_instances created.
#  wlsserver_instance_changes = {
##    for x, y in {
##    for k, v in local.wlsserver_instances : replace(k, "/-[^-]*$/", "") => # remove index suffix
##    { lookup(v, "id", "") = lookup(v, "private_ip", null),            # instances grouped by "pool"
##      wls_machine_name = lookup(lookup(local.enabled_instances,replace(k, "/-[^-]*$/", "")),k).wls_machine_name
##    }...
##    } : x => merge(y...)
#  }
#  wlsserver_instance_changes = { for k, v in oci_core_instance.wlsservers : k => merge(v, lookup(local.enabled_instances, k, {})) }

#  wlsserver_instance_changes = { for k, v in oci_core_instance.wlsservers : k => merge(v, lookup(local.enabled_instances, k, {})) }


#  # Map of pool name to list of instance IP addresses for modes: 'node-pool'
#  wlsserver_nodepool_ips = {
#    for k, v in local.wlsserver_node_pools : k => {
#      for n in lookup(v, "nodes", []) : lookup(n, "id", "") => lookup(n, "private_ip", null)
#    }
#  }
#  wlsserver_instance_changes = { for e in concat([], [
#  for k, v in local.enabled_wlsserver_pools : [
#  for i in range(0, lookup(v, "size", 0)) : merge(v, { oci_core_instance.wlsservers[]
#
#  }) # lookup in pool defaults ports by host_type [index] and set admin,managed,or both list of ports
#  ] if lookup(v, "mode", "") == "instance"
#  ]...) : format("%v-%v", lookup(e, "key"), lookup(e, "index")) => e
#  }
    #TODO: for now only 1 pool.. change to multi pool in the future.
  wlsserver_instance_changes = {
  for key, instance in local.enabled_instances : key => merge(instance, {
    private_ip = lookup(lookup(oci_core_instance.wlsservers, key, {}), "private_ip", null)
  })
  }


  # Yields {<pool name> = {<instance id> = <instance ip>}} for modes: 'node-pool', 'instance'
  wlsserver_pool_ips = merge(local.wlsserver_instance_ips) #, local.wlsserver_nodepool_ips)
}
