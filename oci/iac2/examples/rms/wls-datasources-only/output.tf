# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

# Terraform
#output "state_id" { value = module.wls-migration.state_id }

output "wlserver_config_changes" {
  value = module.wls.wls_config_text_changes
}

output "loaded_ds" {
  value = local.datasources
}

