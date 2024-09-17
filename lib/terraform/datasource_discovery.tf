# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


variable "wls_discovery_filename" {
  type        = string
  description = "Filename - JSON formated - with WLS domain discovered details"
  default     = "wlsdomain.json"
}

#variable "wls_discovery_folder" {
#  type        = string
#  description = "Inventory folder"
#  default     = "inventory"
#}

variable "inventory_path" {
  type = string
  description = "Path to Inventory File (JSON)"
}

# GENERAL INVENTORY FILE
locals {
  wls_domain_name = "wls"
  inventory_file_name = format("%s/%s", var.inventory_path, var.wls_discovery_filename)
  wls_data            = jsondecode(file(local.inventory_file_name))
  wls_topology        = try(local.wls_data["topology"], [])
  wls_machines        = try(local.wls_data["resources"]["Machines"], {})
  wls_servers         = try(local.wls_topology["Server"], [])
}


locals{

  datasource_list= lookup(lookup(local.wls_data,"resources",{}),"JDBCSystemResource",{})
  _ds_list_flatten=flatten([for k,v in local.datasource_list: lookup(lookup(lookup(v,"JdbcResource",{}),"JDBCDriverParams",{}),"URL",{})])
  datasource_temp=try(coalescelist(local._ds_list_flatten),[])
  wls_datasource_distinct_list = distinct(local.datasource_temp)
  datasource_auto_tfvars_template = templatefile("${path.module}/templates/datasource.auto.tfvars.tftpl", {
      datasource = local.wls_datasource_distinct_list
  })
  datasource_auto_tfvars_file = "${var.inventory_path}/datasources.auto.tfvars"
}

resource "local_file" "datasource_auto_tfvars" {
  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }
  content  = local.datasource_auto_tfvars_template
  filename = local.datasource_auto_tfvars_file
}

resource "null_resource" "always_run" {
  triggers = {
    timestamp = "${timestamp()}"
  }
}

output "wls_ds" {
  value = local.wls_datasource_distinct_list
}

output "ds_flatten" {
  value = local._ds_list_flatten
}
