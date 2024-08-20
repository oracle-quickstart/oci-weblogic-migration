# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl


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


