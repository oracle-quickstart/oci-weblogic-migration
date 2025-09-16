# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Common
variable "compartment_id" { type = string }
variable "state_id" { type = string }
variable "resource_name_prefix" {
  type        = string
  description = "Prefix used by the WebLogic for OCI instance of which this compute is part"
}

# Tags
variable "defined_tags" { type = map(string) }
variable "freeform_tags" { type = map(string) }
variable "tag_namespace" { type = string }
variable "use_defined_tags" { type = bool }

# Network
variable "allow_rules_public_lb" { type = any }
variable "allow_rules_wlsservers" { type = any }
variable "allow_rules_adminserver" { type = any }
variable "allow_wlsserver_internet_access" { type = bool }
variable "allow_wlsserver_ssh_access" { type = bool }
variable "allow_bastion_domain_access" { type = bool }
variable "allow_bastion_adminserver_access" { type = bool }
variable "wls_admin_console_port" {type = number}
variable "assign_dns" { type = bool }
variable "bastion_allowed_cidrs" { type = set(string) }
variable "bastion_is_public" { type = bool }
variable "create_bastion" { type = bool }
variable "enable_waf" { type = bool }
variable "ig_route_table_id" { type = string }
variable "load_balancers" { type = string }
variable "nat_route_table_id" { type = string }
variable "vcn_cidrs" { type = list(string) }
variable "vcn_id" { type = string }
variable "nm_port" { type = list(string)}
variable "wlsserver_is_public" { type = bool }
variable "wlsserver_ports" { type = list(string)}
variable "adminserver_ports" { type = list(string)}
variable "allow_adminserver_internet_access" { type=bool }
variable "allow_adminserver_ssh_access" { type = bool }

#TODO: JOI change to adminserver_nsgs
#variable "control_plane_allowed_cidrs" { type = set(string) }
#variable "control_plane_is_public" { type = bool }
#variable "allow_node_port_access" { type = bool }

variable "subnets" {
  type = map(object({
    create    = optional(string)
    id        = optional(string)
    newbits   = optional(string)
    netnum    = optional(string)
    cidr      = optional(string)
    dns_label = optional(string)
  }))
}

variable "nsgs" {
  type = map(object({
    create = optional(string)
    id     = optional(string)
  }))
}
variable "backend_ports" {
  type        = list(number)
  description = "The list of private IP addresses and Ports of the instances for the backend servers"
}

variable "pub_lb_subnet_cidr_value" {
  type        = string
  description = "load_balancer_subnet_cidr"
}

variable "add_load_balancer" {
  type        = bool
  description = "If this variable is true and existing_load_balancer is blank, a new load balancer will be created for the stack. If existing_load_balancer_id is not blank, the specified load balancer will be used"
  default     = true
}