# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# LoadBalancer

variable "create_demo_certificate" {default = false}
variable "load_balancer_shape" {
  default = "flexible"  #TODO: JOI : remove and set to flexible
}
variable "lb_max_bandwidth" {
  default = "100"
}
variable "lb_min_bandwidth" {
  default = "10"
}
variable "existing_load_balancer_id" {
  type= string
  default = null
}
variable "custom_backends" {
  type=list(string)
  default = []
}
