# Copyright (c) 2024, 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  adminserver_nsg_config = try(var.nsgs.adminserver, { create = "never" })
  adminserver_nsg_create = coalesce(lookup(local.adminserver_nsg_config, "create", null), "auto")
  adminserver_nsg_enabled = anytrue([
    local.adminserver_nsg_create == "always",
    alltrue([
      local.adminserver_nsg_create == "auto",
      coalesce(lookup(local.adminserver_nsg_config, "id", null), "none") == "none"
    ]),
  ])
  # Return provided NSG when configured with an existing ID or created resource ID
  adminserver_nsg_id = one(compact([try(var.nsgs.adminserver.id, null), one(oci_core_network_security_group.adminservers[*].id)]))
  adminservers_rules = local.adminserver_nsg_enabled ? merge(
        {
          "Allow TCP egress from adminservers to OCI Services" : {
            protocol         = local.tcp_protocol, port = local.all_ports, destination = local.osn,
            destination_type = local.rule_type_service,
          },
        },
        {
          "Allow ALL egress from adminservers to other adminservers(as)" : {
            protocol         = local.all_protocols, port = local.all_ports, destination = local.adminserver_nsg_id,
            destination_type = local.rule_type_nsg,
          },
        },
#         {
#           "Allow ALL ingress to adminserver from Weblogic Servers(as)" : {
#             protocol    = local.all_protocols, port = local.all_ports, source = local.wlsserver_nsg_id,
#             source_type = local.rule_type_nsg,
#           },
#         },
        {
            for port in var.adminserver_ports :
              "Allow TCP ingress to AdminServer from Managed Servers on port ${port} (as)" => {
                 protocol = local.tcp_protocol, port = port, source = local.wlsserver_nsg_id, source_type = local.rule_type_nsg,
              }
        },
        {
          "Allow ICMP egress from adminservers for path discovery" : {
            protocol         = local.icmp_protocol, port = local.all_ports, destination = local.anywhere,
            destination_type = local.rule_type_cidr,
          },
        },
        {
          "Allow ICMP ingress to adminservers for path discovery" : {
            protocol    = local.icmp_protocol, port = local.all_ports, source = local.anywhere,
            source_type = local.rule_type_cidr,
          },
        },
        var.create_bastion ? {
            "Allow TCP ingress to AdminServer from Bastion on port ${var.wls_admin_console_port} " : {
            protocol = local.tcp_protocol, port = var.wls_admin_console_port, source = local.bastion_nsg_id, source_type = local.rule_type_nsg,
          }
        } : {},
        var.allow_adminserver_internet_access ? {
          "Allow ALL egress from adminservers to internet" : {
            protocol = local.all_protocols, port = local.all_ports, destination = local.anywhere, destination_type = local.rule_type_cidr,
          },
        } : {},

        #TODO: JOI update ports with http listen ports
        local.pub_lb_nsg_enabled ? merge(
          {
            "Allow TCP ingress to adminservers for health check from public load balancers" : {
              protocol = local.tcp_protocol, port = local.health_check_port, source = local.pub_lb_nsg_id, source_type = local.rule_type_nsg,
            },
          },
          {
            for port in var.adminserver_ports :
            "Allow TCP ingress to AdminServer from loadbalancer on port ${port}" => {
               protocol = local.tcp_protocol, port = port , source = local.pub_lb_nsg_id , source_type = local.rule_type_nsg,
            }
          },
          {
            "Allow ALL egress from adminservers to Loadbalancer" : {
              protocol         = local.all_protocols, port = local.all_ports, destination = local.pub_lb_nsg_id,
              destination_type = local.rule_type_nsg,
            },
          }
          ) : {},

    local.bastion_nsg_enabled && var.allow_adminserver_ssh_access ? {
      "Allow SSH ingress to adminservers from bastion" : {
        protocol = local.tcp_protocol, port = local.ssh_port, source = local.bastion_nsg_id, source_type = local.rule_type_nsg,
      }
    } : {},

    local.fss_nsg_enabled ? {
      # See https://docs.oracle.com/en-us/iaas/Content/File/Tasks/securitylistsfilestorage.htm
      # Ingress
      "Allow TCP ingress to adminservers for NFS portmapper from FSS mounts" : {
        protocol = local.tcp_protocol, port = local.fss_nfs_portmapper_port, source = local.fss_nsg_id, source_type = local.rule_type_nsg,
      },
      "Allow UDP ingress to adminservers for NFS portmapper from FSS mounts" : {
        protocol = local.udp_protocol, port = local.fss_nfs_portmapper_port, source = local.fss_nsg_id, source_type = local.rule_type_nsg,
      },
      "Allow TCP ingress to adminservers for NFS from FSS mounts" : {
        protocol = local.tcp_protocol, port_min = local.fss_nfs_port_min, port_max = local.fss_nfs_port_max, source = local.fss_nsg_id, source_type = local.rule_type_nsg,
      },

      # Egress
      "Allow TCP egress from adminservers for NFS portmapper to FSS mounts" : {
        protocol = local.tcp_protocol, port = local.fss_nfs_portmapper_port, destination = local.fss_nsg_id, destination_type = local.rule_type_nsg,
      },
      "Allow UDP egress from adminservers for NFS portmapper to FSS mounts" : {
        protocol = local.udp_protocol, port = local.fss_nfs_portmapper_port, destination = local.fss_nsg_id, destination_type = local.rule_type_nsg,
      },
      "Allow TCP egress from adminservers for NFS to FSS mounts" : {
        protocol = local.tcp_protocol, port_min = local.fss_nfs_port_min, port_max = local.fss_nfs_port_max, destination = local.fss_nsg_id, destination_type = local.rule_type_nsg,
      },
      "Allow UDP egress from adminservers for NFS to FSS mounts" : {
        protocol = local.udp_protocol, port = local.fss_nfs_port_min, destination = local.fss_nsg_id, destination_type = local.rule_type_nsg,
      },
    } : {},
    var.allow_rules_adminserver
    ) : {}
}

resource "oci_core_network_security_group" "adminservers" {
  count          = local.adminserver_nsg_enabled ? 1 : 0
  compartment_id = var.compartment_id
  display_name   = "${var.resource_name_prefix}-adminservers-${var.state_id}"
  vcn_id         = var.vcn_id
  defined_tags   = var.defined_tags
  freeform_tags  = var.freeform_tags
  lifecycle {
    ignore_changes = [defined_tags, freeform_tags, display_name, vcn_id]
  }
}

output "adminserver_nsg_id" {
  value = local.adminserver_nsg_id
}

output "adminserver_port" {
  value       = var.adminserver_ports[0]
}
