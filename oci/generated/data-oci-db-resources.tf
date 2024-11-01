# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
# This is an auto-generated file.

# DB Connection String #0
data "oci_database_autonomous_database" "atp_db_0" {
  count                  = local.is_atp_db_0 ? 1 : 0
  autonomous_database_id = var.atp_db_id_0
}

data "oci_database_db_systems" "ocidb_db_systems_0" {
  count          = local.is_oci_db_0 ? 1 : 0
  compartment_id = var.oci_db_compartment_id_0
  filter {
    name   = "id"
    values = [var.oci_db_dbsystem_id_0]
  }
}


data "oci_database_database" "ocidb_database_0" {
  count       = local.is_ocidb_system_id_available_0 ? 1 : 0
  database_id = var.oci_db_database_id_0
}


data "oci_database_db_home" "ocidb_db_home_0" {
  #  count      = local.is_ocidb_system_id_available_0 && !local.is_db_deleted ? 1 : 0
  count      = local.is_ocidb_system_id_available_0 ? 1 : 0
  #  db_home_id = data.oci_database_database.ocidb_database[0].db_home_id
  db_home_id = data.oci_database_database.ocidb_database_0[0].db_home_id
}
/////////////////////# Datasource #0
