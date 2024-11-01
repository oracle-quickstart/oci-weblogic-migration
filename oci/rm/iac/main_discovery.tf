# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


variable "wls_configured_datasource_text" {
  type = any
  default = {}
  description = "Map with Datasource on-prem text and new oci value. "
}

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
  jdk_home            = distinct([for machine in local.wls_data.resources.Machines : machine.JavaPath])
  domain_path         = local.wls_topology.DomainPath
  oracle_home         = local.wls_topology.OraclePath
  wls_domain_name     = element(split("/", local.domain_path), length(split("/", local.domain_path)) - 1)
  num_oci_instances = length(local.wls_machines)
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
  wls_admin_administrative_port_enabled = try(lookup(local.wls_adminserver_details, "AdministrationPortEnabled", false), false)
  wls_admin_administrative_port         = local.wls_admin_administrative_port_enabled ? try(lookup(local.wls_adminserver_details, "AdministrationPort", null), local.ADMIN_DEFAULT_ADMINISTRATIVE_PORT) : null # Defaults 9002
  wls_admin_t3_port                     = local.ADMIN_DEFAULT_T3_PORT
  wls_admin_t3_ssl_port                 = local.ADMIN_DEFAULT_T3_SSL_PORT
  wls_admin_server_non_unique_ports     = [local.wls_admin_administrative_port, local.wls_admin_listen_port, local.wls_admin_ssl_port, local.wls_admin_t3_port, local.wls_admin_t3_ssl_port]
  wls_admin_server_ports                = distinct(compact(local.wls_admin_server_non_unique_ports))
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
    try(ms["ListenPort"], local.MS_DEFAULT_LISTEN_PORT),
    try(ms["AdministrationPortEnabled"], false) ? try(ms["AdministrationPort"], local.MS_DEFAULT_ADMINISTRATIVE_PORT) : null,
    try(ms["SSL"]["Enabled"], false) ? try(ms["SSL"]["ListenPort"], local.MS_DEFAULT_SSL_LISTEN_PORT) : null,
    lookup(ms, "CoherenceMemberConfig", null) != null ? try(ms["CoherenceMemberConfig"]["UnicastListenPort"], local.COHERENCE_DEFAULT_UNICAST_PORT) : null
  ]
  ])))

  ####################################################################
  #  Get all Application Ports from Managed Servers
  ####################################################################

  __wls_managed_server_listen_ports_not_unique = [for name, ms in local.wls_managed_server_details : try(ms["ListenPort"], local.MS_DEFAULT_LISTEN_PORT)]
  wls_managed_server_listen_ports              = distinct(local.__wls_managed_server_listen_ports_not_unique)
  # ListenPort value could be the same on each managed server. We need only unique ports to add as backends and or firewall rules
  ####################################################################
  # Get all Listen Ports from Managed Servers and format it as  port = instance
  ####################################################################
  #  wls_managed_server_listen_ports_by_instance = distinct(flatten([
  #    for name, ms in local.wls_managed_server_details : {
  #      port     = try(ms["ListenPort"], local.MS_DEFAULT_LISTEN_PORT)
  #      instance = try(ms["Machine"], null)
  #    }
  #  ]))

#  wls_managed_server_listen_ports_by_instance = distinct(flatten(
#    [
#    for pair in setproduct(local.oci_instance_ips, local.wls_managed_server_listen_ports ) : {
#      port     = pair[1]
#      instance = pair[0]
#    }
#    ]
#  ))
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
#
#  __wls_dynamic_server_dynamic_ports_by_instance = [ for pair in setproduct(local.oci_instance_ips, local.__wls_dyn_app_ports_tempo):{
#                                                        instance = pair[0]
#                                                        port     = pair[1]
#                                                     }
#  ]



  ####################################################################
  # Merge DynamicTemplate Listen Ports (Only) and Weblogic Managed Server Listen Ports (Only)
  ####################################################################
#  __wls_all_ports_application_traffic_servers = concat(local.wls_managed_server_listen_ports_by_instance, local.__wls_dynamic_server_dynamic_ports_by_instance)
    wls_all_ports_application_traffic_servers = flatten(distinct(concat(local.wls_managed_server_listen_ports, local.__wls_dyn_app_ports_tempo)))
#  wls_domain_app_traffic_listen_ports_by_priv_ip_tomap          = { for k in local.__wls_all_ports_application_traffic_servers : format("%s-%v", k.instance, k.port) => k... }
#  wls_domain_app_traffic_listen_ports_by_priv_ip_tomap = local.__wls_all_ports_application_traffic_servers


  __wls_dynamic_server_ports = distinct(compact(flatten([
    for name, dynserver in try(lookup(local.wls_topology, "ServerTemplate", {}), {}) :
    [try(dynserver["ListenPort"],null), try(dynserver["AdministrationPort"], null), try(dynserver["SSL"]["ListenPort"], null)]
  ])))

  ####################################################################
  # Merge All Ports found in Dynamic Server and Weblogic Managed Server found in configuration.
  ####################################################################
  wls_domain_all_discovered_ports = distinct(concat(local.wls_managed_server_static_ports, local.__wls_dynamic_server_ports))

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


#  __manual_backend_ips = [{for i, v in lookup(var.lbs.pub_lb, "backends", null) : "${local.wls_domain_name}-vms" => v ...}]


#  instance_private_ips= [
#      for i,v in concat(local.__manual_backend_ips,[one(module.wlsservers[*].wlsserver_pool_ips )]): lookup(v, "${local.wls_domain_name}-vms") if length (v) > 0
#  ]

  instance_private_ips = one(module.wlsservers[*].wlsserver_pool_ips)
  oci_instance_ips = one(module.wlsservers[*].wlsserver_pool_ips)
#  oci_instance_ips = local.instance_private_ips == null ? [] : flatten([for k,v in local.instance_private_ips: values(v)])
#  oci_instance_ips = flatten([for k,v in local.instance_private_ips: values(v)])

  #  single_or_multi_port = try(one(local.wls_managed_server_listen_ports_by_instance).port,)
}


########################
# Locals for Machine and DNS names
##############
locals {
  #  hostnames = try([for machine in local.wls_machines : machine.DETAILS.Hostname],[])
  #  display_name   = format("%s-%s",local.wls_domain_name,n)
  #  hostname_label =  ! can(regex(local.ValidIpAddressRegex,x.DETAILS.Hostname)) ? element(split(local.DOT,x.DETAILS.Hostname),0) : n
  #  oci_instances = [for machines in local.wls_machines : merge(item, {newProp = "XYZ"})]
  #  num_vm_instances = length(local.wls_machines)

  #WHY IS servers and not machines?

  __machine_placement_wlsserver_view  = { for k, wls in local.wls_servers : wls.Machine => k ...}
#  __machine_placement = { for k, wls in local.wls_servers : wls.Machine => k ...}
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




  #  testdomain-vm-instance = {
  #    description = "Testdomain Instance",
  #    mode        = "instance",
  #    size        = 3,
  #    #    node_labels = {
  #    #      "role" = "wlsserver",
  #    #      "domain" = "testdomain",
  #    #      "type" = "adminserver"
  #    #    },
  #    #      hostnames = [[{hostlabel="first", host_type="admin" }],[{hostlabel="second", host_type="managed"}],[{hostlabel="third", host_type="both"}]]
  #    host_details = [{hostlabel="first", host_type="adminserver" },{hostlabel="second", host_type="managedserver"},{hostlabel="third", host_type="both"}]
  #  },

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
  wls_config_text_changes = merge(local.wls_config_text_changes_servers, local.wls_config_text_change_nodemgrs, local.wls_config_text_change_nmproperties, local.wls_config_text_change_datasources)
}

output "wls_config_text_changes" {
  value = local.wls_config_text_changes
}