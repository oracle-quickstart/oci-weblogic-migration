# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

# GENERAL INVENTORY
locals {
  wls_data            = var.wls_inventory_data
  wls_topology        = try(local.wls_data["topology"], [])
  wls_machines        = try(local.wls_data["resources"]["Machines"], {})
  wls_servers         = try(local.wls_topology["Server"], [])
  os_users            = one(distinct([for owner in local.wls_data.resources.Machines : owner.Owner.uname]))
  os_groups           = one(distinct([for owner in local.wls_data.resources.Machines : owner.Owner.gname]))
  os_uid              = one(distinct([for owner in local.wls_data.resources.Machines : owner.Owner.uid]))
  os_gid              = one(distinct([for owner in local.wls_data.resources.Machines : owner.Owner.gid]))
  jdk_home            = element(concat(distinct([for machine in local.wls_data.resources.Machines : machine.JavaPath]), [""]), 0)
}

#GLOBAL SETTINGS
#"AdministrationPortEnabled" : true,
#"ProductionModeEnabled" : true,
locals{
  domain_path         = local.wls_topology.DomainPath
  domain_mount_point  = dirname(local.domain_path)
  oracle_home         = local.wls_topology.OraclePath
  wls_domain_name     = coalesce(try(local.wls_topology["Name"],null),basename(local.domain_path))
  num_oci_instances = length(local.wls_machines)
  wls_global_administration_port_enabled = try(local.wls_topology["AdministrationPortEnabled"],false)
}

# ADMIN SERVER DETAILS
locals {
  wls_adminserver_name    = try(local.wls_topology["AdminServerName"], "")
  wls_adminserver_details = try(local.wls_topology["Server"][local.wls_adminserver_name], "")
  wls_admin_listen_port   = try(lookup(local.wls_adminserver_details, "ListenPort", null), local.ADMIN_DEFAULT_LISTEN_PORT) # 7001
  ##
  #  "SSL" : {
  #    "ListenPort" : 8676,
  #    "Enabled" : true
  #  }
  ##
  wls_admin_ssl_port = lookup(local.wls_adminserver_details["SSL"], "Enabled", false) ? lookup(local.wls_adminserver_details["SSL"], "ListenPort", local.ADMIN_DEFAULT_SSL_LISTEN_PORT) : null # Default 7002
  #"adminserver" : {
  #  "ListenPort" : 8675,
  #  "AdministrationPortEnabled" : true,
  #  "Machine" : "machinename1",
  #  "AdministrationPort" : 9875,
  #  "ListenAddress" : "host.oraclevcn.com",
  #  "SSL" : {
  #    "ListenPort" : 8676,
  #    "Enabled" : true
  #  },
  wls_admin_administrative_port_enabled = try(local.wls_adminserver_details["AdministrationPortEnabled"], false)
  #Rules for Administrative Port
  # Global AdministrationPortEnabled and AdministrationPort (not defined) = Default Port 9002
  # NO Global AdministrationPortEnabled and Admin Server AdministrationPortEnabled (defined) and  NO AdminPort= Default Port 9002
  # AdministrationPort (defined) = AdministrationPort

  _wls_admin_admin_port_tmp=try(local.wls_adminserver_details["AdministrationPort"],local.ADMIN_DEFAULT_ADMINISTRATIVE_PORT) # Defaults 9002
  wls_admin_administrative_port=anytrue([
    contains(keys(local.wls_adminserver_details),"AdministrationPort"),
    local.wls_admin_administrative_port_enabled,
    local.wls_global_administration_port_enabled
  ]) ? local._wls_admin_admin_port_tmp : null


  wls_admin_t3_port                     = local.ADMIN_DEFAULT_T3_PORT
  wls_admin_t3_ssl_port                 = local.ADMIN_DEFAULT_T3_SSL_PORT
  wls_admin_server_non_unique_ports     = [local.wls_admin_administrative_port, local.wls_admin_listen_port, local.wls_admin_ssl_port, local.wls_admin_t3_port, local.wls_admin_t3_ssl_port]
  _wls_admin_network_channel_port_definition = distinct(compact(flatten([
  for name, channel in try(lookup(local.wls_adminserver_details, "NetworkAccessPoint", {}), {}) :
  [
    try(channel["PublicPort"], null),
    try(channel["ListenPort"], null)
  ]
  ])))
  wls_admin_server_ports                = distinct(compact(concat(local.wls_admin_server_non_unique_ports,local._wls_admin_network_channel_port_definition)))
}

## MANAGED SERVER DETAILS
locals {
  wls_managed_server_details = {
  for key, ms in try(
    lookup(local.wls_topology, "Server", null), {}) : key => ms
  if key != local.wls_adminserver_name
  }

  ####################################################################
  # Get all Ports from Managed Servers under Servers - Static
  ####################################################################
  wls_managed_server_static_ports = distinct(compact(flatten([
  for name, ms in local.wls_managed_server_details :
  [
      try(ms["ListenPortEnabled"], true) ? try(ms["ListenPort"], local.MS_DEFAULT_LISTEN_PORT) : null,
    #try(ms["AdministrationPortEnabled"], false) ? try(ms["AdministrationPort"], local.MS_DEFAULT_ADMINISTRATIVE_PORT) : null,
    anytrue([
      contains(keys(ms),"AdministrationPort"),
      try(ms["AdministrationPortEnabled"], false),
      local.wls_global_administration_port_enabled
    ]) ? try(ms["AdministrationPort"],local.MS_DEFAULT_ADMINISTRATIVE_PORT) : null,
    try(ms["SSL"]["Enabled"], false) ? try(ms["SSL"]["ListenPort"], local.MS_DEFAULT_SSL_LISTEN_PORT) : null,
    lookup(ms, "CoherenceMemberConfig", null) != null ? try(ms["CoherenceMemberConfig"]["UnicastListenPort"], local.COHERENCE_DEFAULT_UNICAST_PORT) : null
  ]
  ])))

  ####################################################################
  # Discover Network Channel Ports from Managed Servers
  ####################################################################

  _wls_managed_server_network_channel_port_definition = distinct(compact(flatten([
    for name, ms in local.wls_managed_server_details :
    [
      for name, channel in try(ms["NetworkAccessPoint"], {}) :
      [
        try(channel["PublicPort"], null),
        try(channel["ListenPort"], null)
      ]
    ]
  ])))

  ####################################################################
  #  Get all Application Ports from Managed Servers
  ####################################################################
  # Differentiate Listen Port on or off to switch to SSL Listen Ports.

  __wls_managed_server_plain_listen_ports_not_unique = [for name, ms in local.wls_managed_server_details :
    try(ms["ListenPort"], local.MS_DEFAULT_LISTEN_PORT) if try(ms["ListenPortEnabled"], true)
  ]

  __wls_managed_server_ssl_listen_ports_not_unique = [for name, ms in local.wls_managed_server_details :
    try(ms["SSL"]["ListenPort"], local.MS_DEFAULT_SSL_LISTEN_PORT)  if try(ms["SSL"]["Enabled"], false)
  ]

  __wls_managed_server_listen_ports_not_unique = concat(local.__wls_managed_server_plain_listen_ports_not_unique,local.__wls_managed_server_ssl_listen_ports_not_unique)

  # ListenPort value could be the same on each managed server. We need only unique ports to add as backends and or firewall rules
  wls_managed_server_listen_ports              = distinct(local.__wls_managed_server_listen_ports_not_unique)



  #########################################################
  ## DYNAMIC SERVER FROM DYNAMIC TEMPLATES CONFIG
  ###########################################################################
  # How to calculate Ports when Dynamic Server is enabled.?
  #
  #  "Cluster" : {
  #  "testcluster" : {
  #  },
  #  "testdynamiccluster" : {
  #    "DynamicServers" : {
  #      "CalculatedMachineNames" : true,
  #      "ServerNamePrefix" : "testdynamicserver",
  #      "MaximumDynamicServerCount" : 3,
  #      "ServerTemplate" : "testdynamicserverTemplate",
  #      "DynamicClusterSize" : 3
  #############################################################################

  #############################################################################
  # Merge Cluster DynamicServer.ServerTemplates with ServerTemplates
  #############################################################################
  __wls_merged_templates_details = [
  for k, att in local.wls_topology.Cluster :
  merge(att, local.wls_topology.ServerTemplate[att.DynamicServers.ServerTemplate]) if try(att.DynamicServers, null) != null
  ]
  /*Example: Result after merge templates
  #
  + {
          + AdministrationPort     = 9002
          + Cluster                = "testdynamiccluster"
          + DynamicServers         = {
              + CalculatedMachineNames    = true
              + DynamicClusterSize        = 3
              + MaximumDynamicServerCount = 3
              + ServerNamePrefix          = "testdynamicserver"
              + ServerTemplate            = "testdynamicserverTemplate"
            }
          + JTAMigratableTarget    = {
              + Cluster         = "testdynamiccluster"
              + MigrationPolicy = "manual"
            }
          + ListenPort             = 8900
          + SSL                    = {
              + Enabled    = true
              + ListenPort = 8910
            }
          + ServerDiagnosticConfig = {
              + WldfDiagnosticVolume = "Low"
            }
          + VirtualMachineName     = "testdomain_testdynamic"
        },
  */
  ################################################################################

  wls_dynamic_server_app_traffic_port = {for k, v in local.__wls_merged_templates_details : v.Cluster => [for index in range(try(v.DynamicServers.MaximumDynamicServerCount, 0)) : (v.ListenPort + index)]}

  __wls_dyn_app_ports_tempo                         = flatten([for k, v in local.wls_dynamic_server_app_traffic_port: v])

  #############################################################################
  # Builds a list of ports and instance IP to be used by Load Balancer Backend
  #############################################################################



  ####################################################################
  # Merge DynamicTemplate Listen Ports (Only) and Weblogic Managed Server Listen Ports (Only)
  ####################################################################

    wls_all_ports_application_traffic_servers = flatten(distinct(concat(local.wls_managed_server_listen_ports, local.__wls_dyn_app_ports_tempo)))


  __wls_dynamic_server_ports = distinct(compact(flatten([
    for name, dynserver in try(lookup(local.wls_topology, "ServerTemplate", {}), {}) :
    [try(dynserver["ListenPort"],null), try(dynserver["AdministrationPort"], null), try(dynserver["SSL"]["ListenPort"], null)]
  ])))

  ####################################################################
  # Merge All Ports found in Dynamic Server and Weblogic Managed Server found in configuration.
  ####################################################################
  wls_domain_all_discovered_ports = distinct(concat(local.wls_managed_server_static_ports, local._wls_managed_server_network_channel_port_definition, local.__wls_dynamic_server_ports))

}

/*
  Locals to include Instance IPs, Instance Ports, Instance Ports Per Instance IP
*/
locals {

  /* module.wlsservers[*].wlsserver_pool_ips returns ips wrapped into domain-vms key
  {
          + testdomain-vms = {
              + "ocid1.instance.oc1.iad.anuwcljtdoggtjacfghcdpozirjovehqgx5hvt4nxxxxxxxszlfkq" = "10.0.90.251"
              + "ocid1.instance.oc1.iad.anuwcljtdoggtjayyyyyyyyyyyyyyyyyyyyyyyyyyyyqm7e2svdba" = "10.0.88.224"
            }
  },
  var.lbs.pub_lb,"backends"  should return a list of IPs when configured ["192.168.X.Y","192.168.Z.Z"]
  */

  instance_private_ips = one(module.wlsservers[*].wlsserver_pool_ips)
  oci_instance_ips = one(module.wlsservers[*].wlsserver_pool_ips)

}


########################
# Locals for Machine and DNS names
##############
locals {


  __machine_placement_wlsserver_view  = { for k, wls in local.wls_servers : wls.Machine => k ...}
  __machine_placement = { for k, wls in try(local.wls_data.resources.Machines,{}) : k => try(lookup(local.__machine_placement_wlsserver_view,k), [])}
  __wls_machines_pivot = try(local.wls_data.resources.Machines, {})
  __host_details = [ for k, wls in local.__machine_placement : merge(
      contains(wls, local.wls_adminserver_name) && length(wls) > 1 ? {
        #TODO: JOI: If value is ip address, then should it be replaced with Machine hostanme ?  and not assign new hostname ?
        hostlabel = !can(regex(local.ValidIpAddressRegex, lookup(local.__wls_machines_pivot, k).DETAILS.Hostname)) ? element(split(local.DOT, lookup(local.__wls_machines_pivot, k).DETAILS.Hostname), 0) : local.ASSIGN_NEW,
        host_type = local.BOTH_KEY
        wls_machine_name = k
      } :  contains(wls, local.wls_adminserver_name) && length(wls) == 1?  {
        hostlabel = !can(regex(local.ValidIpAddressRegex, lookup(local.__wls_machines_pivot, k).DETAILS.Hostname)) ? element(split(local.DOT, lookup(local.__wls_machines_pivot, k).DETAILS.Hostname), 0) : local.ASSIGN_NEW,
        host_type = local.ADMINSERVER_KEY ,
        wls_machine_name = k
      }: !contains(wls, local.wls_adminserver_name) ?  {
        # Machines with placements or with no placements. Default set to Managed Server
        hostlabel = !can(regex(local.ValidIpAddressRegex, lookup(local.__wls_machines_pivot, k).DETAILS.Hostname)) ? element(split(local.DOT, lookup(local.__wls_machines_pivot, k).DETAILS.Hostname), 0) : local.ASSIGN_NEW,
        host_type = local.MANAGED_SERVER_KEY ,
        wls_machine_name = k
      }: {
      # Code should not reach this point.
      }
    )
  ]


  wls_instance_params = {
    "${local.wls_domain_name}-vms" = {
      description  = "${local.wls_domain_name} Instances",
      mode         = "instance",
      size         = local.num_oci_instances,
      host_details = local.__host_details,
      #    node_labels = {
      #      "role" = "wlsserver",
      #      "domain" = "testdomain",
      #      "type" = "adminserver"
      #    },
    }
  }

}

# Text to replace in Weblogic config files
locals {
  # Weblogic Servers Text to be replaced with new hosts
  wls_config_text_changes_servers = {
    for k, wls in local.wls_servers : lookup(wls, "ListenAddress", "") =>
    lookup(wls, "ListenAddress", "") == local.LISTEN_ALL_IPS ? local.LISTEN_ALL_IPS :
    lookup(wls, "ListenAddress", "") == local.LISTEN_127_0_0_1 ? local.LISTEN_127_0_0_1 :
    lookup(wls, "ListenAddress", "") == local.LOCALHOST_KEY ? local.LOCALHOST_KEY :
    element(split(local.DOT, lookup(local.__wls_machines_pivot, wls.Machine).DETAILS.Hostname), 0) # Weblogic Servers
  ...}


  # # Machines Servers Text to be replaced with new hosts
  wls_config_text_change_nodemgrs = {
    for k, wls in try(local.wls_topology["Machine"], {}) : (wls["NodeManager"].ListenAddress) =>
    (wls["NodeManager"].ListenAddress) == local.LISTEN_ALL_IPS ? local.LISTEN_ALL_IPS :
    (wls["NodeManager"].ListenAddress) == local.LISTEN_127_0_0_1 ? local.LISTEN_127_0_0_1 :
    (wls["NodeManager"].ListenAddress) == local.LOCALHOST_KEY ? local.LOCALHOST_KEY :
    element(split(local.DOT, lookup(local.__wls_machines_pivot, k).DETAILS.Hostname), 0) # Machines
  }

  # $DOMAIN_HOME/nodemanager/nodemanger.properties text to replaced with new hosts
  wls_config_text_change_nmproperties = {
    try(local.wls_topology["NMProperties"].ListenAddress, "") = (try(local.wls_topology["NMProperties"].ListenAddress, "") == local.LISTEN_ALL_IPS ? local.LISTEN_ALL_IPS :
      try(local.wls_topology["NMProperties"].ListenAddress, "") == local.LISTEN_127_0_0_1 ? local.LISTEN_127_0_0_1 :
      try(local.wls_topology["NMProperties"].ListenAddress, "") == local.LOCALHOST_KEY ? local.LOCALHOST_KEY :
    element(split(local.DOT, lookup(local.__wls_machines_pivot, local.wls_servers[local.wls_adminserver_name].Machine).DETAILS.Hostname), 0))
  }

  # rules for datasource changes.
  # on_prem != "" &&
  # ds.on_prem != ds.oci
  # ds.oci != ""
  wls_config_text_change_datasources  = {
       for k, ds in try(var.wls_configured_datasource_text == null ? {}: var.wls_configured_datasource_text,{}) : (ds.on_prem) =>
        ds.oci if ds.on_prem != "" && ds.on_prem != ds.oci && ds.oci != ""
  }

  wls_config_text_changes = merge(local.wls_config_text_changes_servers, local.wls_config_text_change_nodemgrs, local.wls_config_text_change_nmproperties)
}

output "wls_config_text_changes" {
  value = local.wls_config_text_changes
}