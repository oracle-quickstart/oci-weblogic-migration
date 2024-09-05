# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


variable "wls_discovery_filename" {
  type        = string
  description = "Filename - JSON formated - with WLS domain discovered details"
  default     = "wlsdomain.json"
}

variable "wls_discovery_folder" {
  type        = string
  description = "Inventory folder"
  default     = "inventory"
}

variable "wls_configured_datasource_text" {
  type = any
  default = {}
  description = "Map with Datasource on-prem text and new oci value. "
}

#variable "inventory_file" {
#  default=""
#}

# GENERAL INVENTORY FILE
locals {
  inventory_file_name = format("%s/%s/%s", path.module, var.wls_discovery_folder, var.wls_discovery_filename)
  wls_data            = jsondecode(file(local.inventory_file_name))
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
  wls_admin_administrative_port_enabled = try(lookup(local.wls_adminserver_details, "AdministrationPortEnabled", null), false)
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
  # Get all Listen Ports from Managed Servers and format it as  port = instance
  ####################################################################
#  wls_managed_server_listen_ports_by_instance = distinct(flatten([
#    for name, ms in local.wls_managed_server_details : {
#      port     = try(ms["ListenPort"], local.MS_DEFAULT_LISTEN_PORT)
#      instance = try(ms["Machine"], null)
#    }
#  ]))

  wls_managed_server_listen_ports_by_instance = distinct(flatten(
    [for pair in setproduct(local.oci_instance_ips, [for name,ms in local.wls_managed_server_details: try(ms["ListenPort"], local.MS_DEFAULT_LISTEN_PORT) ] ) : {
      port = pair[1]
      instance = pair[0]
    }]
  ))

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
  wls_merged_templates_details = [for k, att in local.wls_topology.Cluster :
    merge(att, local.wls_topology.ServerTemplate[att.DynamicServers.ServerTemplate]) if try(att.DynamicServers, null) != null
  ]


  num_oci_instances = length(local.wls_machines)

  #TODO JOI: Change to OCI Instance private IPs
#  backend_ips= local.instance_private_ips
#  oci_instance_ips = flatten([for k, v in local.wls_machines : k])
  oci_instance_ips = local.instance_private_ips == null ? [] : local.instance_private_ips
  #############################################################################
  # Builds a list of ports and instance IP to be used by Load Balancer Backend
  #############################################################################
  wls_dynamic_server_dynamic_ports_by_instance = distinct(flatten([
    for k, v in local.wls_merged_templates_details : [
      for pair in setproduct(local.oci_instance_ips, local.num_oci_instances == v.DynamicServers.MaximumDynamicServerCount ? [v.ListenPort] : flatten(range(v.ListenPort, (v.ListenPort + ceil(v.DynamicServers.MaximumDynamicServerCount / local.num_oci_instances))))) : {
        port     = pair[1]
        instance = pair[0]
      }
    ]
  ]))

  ####################################################################
  # Merge DynamicTemplate Listen(only) Ports and Weblogic Listen (only) Ports
  ####################################################################
  lb_backends_managed_servers = concat(local.wls_managed_server_listen_ports_by_instance, local.wls_dynamic_server_dynamic_ports_by_instance)
  lb_backends_to_map          = { for k in local.lb_backends_managed_servers : format("%s-%s", k.instance, k.port) => k... }

  #  wls_dynamic_server_enabled = [for cluster in local.wls_topology["Cluster"] : cluster["DynamicServer"]["ServerTemplate"] if try(cluster["DynamicServer"], false)]
  wls_dynamic_server_ports = distinct(compact(flatten([
    for name, dynserver in try(lookup(local.wls_topology, "ServerTemplate", {}), {}) :
    [try(dynserver["ListenPort"]), try(dynserver["AdministrationPort"], null), try(dynserver["SSL"]["ListenPort"], null)]
  ])))

  ####################################################################
  # Merge Dynamic Server All Ports and Weblogic Static (all) Ports
  ####################################################################
  wls_managed_server_ports = distinct(concat(local.wls_managed_server_static_ports, local.wls_dynamic_server_ports))


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

  machine_placement  = { for k, wls in local.wls_servers : wls.Machine => k... }
  wls_machines_pivot = try(local.wls_data.resources.Machines, {})
  host_details = [for k, wls in local.machine_placement : {
    #TODO: JOI: If value is ip address, then should it be replaced with Machine hostanme ?  and not assign new hostname ?
    hostlabel        = !can(regex(local.ValidIpAddressRegex, lookup(local.wls_machines_pivot, k).DETAILS.Hostname)) ? element(split(local.DOT, lookup(local.wls_machines_pivot, k).DETAILS.Hostname), 0) : local.ASSIGN_NEW,
    host_type        = contains(wls, local.wls_adminserver_name) && length(wls) > 1 ? local.BOTH_KEY : !contains(wls, local.wls_adminserver_name) ? local.MANAGED_SERVER_KEY : local.ADMINSERVER_KEY,
    wls_machine_name = k
    }
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
      host_details = local.host_details,
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
    element(split(local.DOT, lookup(local.wls_machines_pivot, wls.Machine).DETAILS.Hostname), 0) # Weblogic Servers
  ...}


  # # Machines Servers Text to be replaced with new hosts
  wls_config_text_change_nodemgrs = {
    for k, wls in try(local.wls_topology["Machine"], {}) : (wls["NodeManager"].ListenAddress) =>
    (wls["NodeManager"].ListenAddress) == local.LISTEN_ALL_IPS ? local.LISTEN_ALL_IPS :
    (wls["NodeManager"].ListenAddress) == local.LISTEN_127_0_0_1 ? local.LISTEN_127_0_0_1 :
    (wls["NodeManager"].ListenAddress) == local.LOCALHOST_KEY ? local.LOCALHOST_KEY :
    element(split(local.DOT, lookup(local.wls_machines_pivot, k).DETAILS.Hostname), 0) # Machines
  }

  # $DOMAIN_HOME/nodemanager/nodemanger.properties text to replaced with new hosts
  wls_config_text_change_nmproperties = {
    try(local.wls_topology["NMProperties"].ListenAddress, "") = (try(local.wls_topology["NMProperties"].ListenAddress, "") == local.LISTEN_ALL_IPS ? local.LISTEN_ALL_IPS :
      try(local.wls_topology["NMProperties"].ListenAddress, "") == local.LISTEN_127_0_0_1 ? local.LISTEN_127_0_0_1 :
      try(local.wls_topology["NMProperties"].ListenAddress, "") == local.LOCALHOST_KEY ? local.LOCALHOST_KEY :
    element(split(local.DOT, lookup(local.wls_machines_pivot, local.wls_servers[local.wls_adminserver_name].Machine).DETAILS.Hostname), 0))
  }

  # rules for datasource changes.
  # on_prem != "" &&
  # ds.on_prem != ds.oci
  # ds.oci != ""
  wls_config_text_change_datasources  = {
       for k, ds in try(var.wls_configured_datasource_text,{}) : (ds.on_prem) =>
        ds.oci if ds.on_prem != "" && ds.on_prem != ds.oci && ds.oci != ""
  }
  wls_config_text_changes = merge(local.wls_config_text_changes_servers, local.wls_config_text_change_nodemgrs, local.wls_config_text_change_nmproperties, local.wls_config_text_change_datasources)
}

output "wls_config_text_changes" {
  value = local.wls_config_text_changes
}