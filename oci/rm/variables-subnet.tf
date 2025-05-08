# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

variable "bastion_subnet_create" { default = true }
variable "int_lb_subnet_create" { default = false }
variable "pub_lb_subnet_create" { default = true }
variable "wlsserver_subnet_create" { default = false }

variable "bastion_subnet_newbits" { default = 13 }
variable "int_lb_subnet_newbits" { default = 11 }
variable "pub_lb_subnet_newbits" { default = 11 }
variable "wlsserver_subnet_newbits" { default = 2 }

variable "wlsserver_subnet_cidr" {
  type        = string
  description = "CIDR for weblogic subnet"
  default     = ""
}

variable "bastion_subnet_id" {
  type    = string
  default = null
}
variable "int_lb_subnet_id" {
  type    = string
  default = null
}
variable "pub_lb_subnet_id" {
  type    = string
  default = null
}
variable "wlsserver_subnet_id" {
  type    = string
  default = null
}