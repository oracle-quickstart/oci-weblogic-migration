# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

variable "existing_load_balancer_id" {
  type        = string
  description = "The OCID of an existing load balancer. If set, use the existing load balancer and add the stack nodes to the backend set of the existing load balancer. Set add_load_balancer to true in order for this value to take effect"
  default =  null
}


variable "add_load_balancer" {
  type        = bool
  description = "If this variable is true and existing_load_balancer is blank, a new load balancer will be created for the stack. If existing_load_balancer_id is not blank, the specified load balancer will be used"
  default     = true
}


variable "lb_max_bandwidth" {
  type        = number
  description = "Bandwidth in Mbps that determines the maximum bandwidth (ingress plus egress) that the load balancer can achieve"
  default =  800
}

variable "lb_min_bandwidth" {
  type        = number
  description = "Bandwidth in Mbps that determines the maximum bandwidth (ingress plus egress) that the load balancer can achieve"
  default =  100
}

variable "add_existing_nsg" {
  type        = bool
  description = "Use an existing network security group"
  default     = false
}

variable "load_balancers" {
  default     = "both"
  description = "The type of subnets to create for load balancers."
  type        = string
  validation {
    condition     = contains(["public", "internal", "both"], var.load_balancers)
    error_message = "Accepted values are public, internal or both."
  }
}

variable "preferred_load_balancer" {
  default     = "public"
  description = "The preferred load balancer subnets that OKE will automatically choose when creating a load balancer. Valid values are 'public' or 'internal'. If 'public' is chosen, the value for load_balancers must be either 'public' or 'both'. If 'private' is chosen, the value for load_balancers must be either 'internal' or 'both'. NOTE: Service annotations for internal load balancers must still be specified regardless of this setting. See <a href=https://github.com/oracle/oci-cloud-controller-manager/blob/master/docs/load-balancer-annotations.md>Load Balancer Annotations</a> for more information."
  type        = string
  validation {
    condition     = contains(["public", "internal"], var.preferred_load_balancer)
    error_message = "Accepted values are public or internal."
  }
}

variable "lb_reserved_public_ip_id" {
  type        = string
  description = "The OCID of a reserved public IP for the load balancer of the stack"
  default     = null
}


variable "backendset_name_for_existing_load_balancer" {
  type        = string
  description = "The name of an existing backend set in an existing load balancer. The backend set should not have any backend. The WebLogic VMs will be added as backends to this backend set"
  default = null
}

variable "lb_shape" {
  default = {
    int_lb = { shape="10Mbps", min = 100,max=100}
    pub_lb = { shape="100Mbps",min = 100,max=100}
  }
  description = "Default shape of the created Load Balancer resource."
  type        = map(object({
    min = optional(number)
    max = optional(number)
    shape = optional(string)
  }))
}

variable "lbs" {
  default = {
    int_lb = {}
    pub_lb = {}
  }
  type = map(object({
    create = optional(string)
    id = optional(string)
    backends = optional(list(string))
}))
}
  # TODO: JOI : set validations back
#  validation {
#    condition = alltrue([
#    for k, v in values(var.nsgs) : contains(["never", "auto", "always"], coalesce(v.create, "auto"))
#    ])
#    error_message = "Accepted values for 'create' are 'never', 'auto', or 'always'."
#  }
#  validation {
#    condition = alltrue([
#    for v in flatten([for k, v in var.nsgs : keys(v)]) : contains(["create", "id"], v)
#    ])
#    error_message = format("Invalid NSG configuration keys: %s", jsonencode(distinct([
#    for v in flatten([for k, v in var.nsgs : keys(v)]) : v if !contains(["create", "id"], v)
#    ])))
#  }
#  validation {
#    condition = alltrue([
#    for k, v in var.nsgs :
#    contains(["bastion", "int_lb", "pub_lb", "managedserver", "adminserver", "fss"], k)
#    ])
#    error_message = format("Invalid NSG keys: %s", jsonencode([for k, v in var.nsgs : k
#    if !contains(["bastion", "int_lb", "pub_lb", "managedserver", "adminserver","fss"], k)
#    ]))
#  }
