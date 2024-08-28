# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  datasources = var.update_any_ds? {
     1 = {
       on_prem = var.ds_1
       oci = var.editable_ds_1 != "n/a" ? var.editable_ds_1: ""
     }
     2 = {
       on_prem = var.ds_2
       oci = var.editable_ds_2
     }
    3 = {
      on_prem = var.ds_3
      oci = var.editable_ds_3
    }
    4 = {
      on_prem = var.ds_4
      oci = var.editable_ds_4
    }
    5 = {
      on_prem = var.ds_5
      oci = var.editable_ds_5
    }
    6 = {
      on_prem = var.ds_6
      oci = var.editable_ds_6
    }
    7 = {
      on_prem = var.ds_7
      oci = var.editable_ds_7
    }
    8 = {
      on_prem = var.ds_8
      oci = var.editable_ds_8
    }
    9 = {
      on_prem = var.ds_9
      oci = var.editable_ds_9
    }
    10 = {
      on_prem = var.ds_10
      oci = var.editable_ds_10
    }
  } : {}
}