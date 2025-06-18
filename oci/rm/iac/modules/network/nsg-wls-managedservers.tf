# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  wlsserver_nsg_config = try(var.nsgs.managedserver, { create = "never" })
  wlsserver_nsg_create = coalesce(lookup(local.wlsserver_nsg_config, "create", null), "auto")
  wlsserver_nsg_enabled = anytrue([
    local.wlsserver_nsg_create == "always",
    alltrue([
      local.wlsserver_nsg_create == "auto",
      coalesce(lookup(local.wlsserver_nsg_config, "id", null), "none") == "none"
    ]),
  ])
  # Return provided NSG when configured with an existing ID or created resource ID
  wlsserver_nsg_id = one(compact([try(var.nsgs.managedserver.id, null), one(oci_core_network_security_group.wlsservers[*].id)]))
  wlsservers_rules = local.wlsserver_nsg_enabled ? merge(
    {
      "Allow TCP egress from wlsservers to OCI Services" : {
        protocol = local.tcp_protocol, port = local.all_ports, destination = local.osn, destination_type = local.rule_type_service,
      },

      "Allow ALL egress from Weblogic Mananged Servers to other Weblogic Managed Servers" : {
        protocol = local.all_protocols, port = local.all_ports, destination = local.wlsserver_nsg_id, destination_type = local.rule_type_nsg,
      },
      "Allow ALL ingress to Managed Servers from other Managed Servers" : {
        protocol = local.all_protocols, port = local.all_ports, source = local.wlsserver_nsg_id, source_type = local.rule_type_nsg,
      },
      #TODO: JOI update Admin Server Port
      "Allow TCP egress from Managed Servers to Admin Server" : {
        protocol = local.tcp_protocol, port = local.all_ports, destination = local.adminserver_nsg_id, destination_type = local.rule_type_nsg,
      },
      "Allow ALL ingress to Managed Servers from Admin Server" : {
        protocol = local.all_protocols, port = local.all_ports, source = local.adminserver_nsg_id, source_type = local.rule_type_nsg,
      },
#      "Allow TCP egress to  control plane from wlsservers for health check" : {
#        protocol = local.tcp_protocol, port = local.kubelet_api_port, destination = local.control_plane_nsg_id, destination_type = local.rule_type_nsg,
#      },
#      "Allow ALL ingress to wlsservers from  control plane for webhooks served by wlsservers" : {
#        protocol = local.all_protocols, port = local.all_ports, source = local.control_plane_nsg_id, source_type = local.rule_type_nsg,
#      },
      "Allow ICMP egress from wlsservers for path discovery" : {
        protocol = local.icmp_protocol, port = local.all_ports, destination = local.anywhere, destination_type = local.rule_type_cidr,
      },
      "Allow ICMP ingress to wlsservers for path discovery" : {
        protocol = local.icmp_protocol, port = local.all_ports, source = local.anywhere, source_type = local.rule_type_cidr,
      },
      "Allow TCP ingress from Managed Servers to Node Manager port" : {
        protocol = local.tcp_protocol, port = var.nm_port[0], source = local.wlsserver_nsg_id, source_type = local.rule_type_nsg,
      },
    },
    var.allow_wlsserver_internet_access ? {
      "Allow ALL egress from wlsservers to internet" : {
        protocol = local.all_protocols, port = local.all_ports, destination = local.anywhere, destination_type = local.rule_type_cidr,
      },
    } : {},

    local.int_lb_nsg_enabled ? {
      "Allow TCP ingress to wlsservers from internal load balancers" : {
        protocol = local.tcp_protocol, port_min = local.node_port_min, port_max = local.node_port_max, source = local.int_lb_nsg_id, source_type = local.rule_type_nsg,
      },
      "Allow TCP ingress to wlsservers for health check from internal load balancers" : {
        protocol = local.tcp_protocol, port = local.health_check_port, source = local.int_lb_nsg_id, source_type = local.rule_type_nsg,
      },
    } : {},
    #TODO: JOI update ports with http listen ports
    local.pub_lb_nsg_enabled ? merge(
      {
        "Allow TCP ingress to wlsservers from public load balancers" : {
          protocol     = local.tcp_protocol,
          port_min     = local.node_port_min,
          port_max     = local.node_port_max,
          source       = local.pub_lb_nsg_id,
          source_type  = local.rule_type_nsg,
        },
        "Allow TCP ingress to wlsservers for health check from public load balancers" : {
          protocol     = local.tcp_protocol,
          port         = local.health_check_port,
          source       = local.pub_lb_nsg_id,
          source_type  = local.rule_type_nsg,
        }
      },
      {
        for p in var.backend_ports :
        "Allow TCP ingress to wlsservers on port ${p} from CIDR" => {
        protocol     = local.tcp_protocol,
        port         = p,
        source       = var.pub_lb_subnet_cidr_value,
        source_type  = "CIDR_BLOCK",
      }
      }
    ) : {},

    # Allow Bastion ssh access to Managed Server
    local.bastion_nsg_enabled && var.allow_wlsserver_ssh_access ? {
      "Allow SSH ingress to wlsservers from bastion" : {
        protocol = local.tcp_protocol, port = local.ssh_port, source = local.bastion_nsg_id, source_type = local.rule_type_nsg,
      }
    } : {},

    local.fss_nsg_enabled ? {
      # See https://docs.oracle.com/en-us/iaas/Content/File/Tasks/securitylistsfilestorage.htm
      # Ingress
      "Allow TCP ingress to wlsservers for NFS portmapper from FSS mounts" : {
        protocol = local.tcp_protocol, port = local.fss_nfs_portmapper_port, source = local.fss_nsg_id, source_type = local.rule_type_nsg,
      },
      "Allow UDP ingress to wlsservers for NFS portmapper from FSS mounts" : {
        protocol = local.udp_protocol, port = local.fss_nfs_portmapper_port, source = local.fss_nsg_id, source_type = local.rule_type_nsg,
      },
      "Allow TCP ingress to wlsservers for NFS from FSS mounts" : {
        protocol = local.tcp_protocol, port_min = local.fss_nfs_port_min, port_max = local.fss_nfs_port_max, source = local.fss_nsg_id, source_type = local.rule_type_nsg,
      },

      # Egress
      "Allow TCP egress from wlsservers for NFS portmapper to FSS mounts" : {
        protocol = local.tcp_protocol, port = local.fss_nfs_portmapper_port, destination = local.fss_nsg_id, destination_type = local.rule_type_nsg,
      },
      "Allow UDP egress from wlsservers for NFS portmapper to FSS mounts" : {
        protocol = local.udp_protocol, port = local.fss_nfs_portmapper_port, destination = local.fss_nsg_id, destination_type = local.rule_type_nsg,
      },
      "Allow TCP egress from wlsservers for NFS to FSS mounts" : {
        protocol = local.tcp_protocol, port_min = local.fss_nfs_port_min, port_max = local.fss_nfs_port_max, destination = local.fss_nsg_id, destination_type = local.rule_type_nsg,
      },
      "Allow UDP egress from wlsservers for NFS to FSS mounts" : {
        protocol = local.udp_protocol, port = local.fss_nfs_port_min, destination = local.fss_nsg_id, destination_type = local.rule_type_nsg,
      },
    } : {},
    var.allow_rules_wlsservers
    ) : {}
}

resource "oci_core_network_security_group" "wlsservers" {
  count          = local.wlsserver_nsg_enabled ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.resource_name_prefix}-wlsservers-${var.state_id}"
  vcn_id         = var.vcn_id
  defined_tags   = var.defined_tags
  freeform_tags  = var.freeform_tags
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags, display_name, vcn_id]
  }
}



output "wlsserver_nsg_id" {
  value = local.wlsserver_nsg_id
}
