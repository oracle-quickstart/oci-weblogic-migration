# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
# This is an auto-generated file.

locals {
    jdbc_driver_thin_string="jdbc:oracle:thin:@"

    #  For DB Systems
    #   - find database home
    #   - get field connection_strings and cdb_default to have easy connect string.
    #   - if pdbname is !="", replace cdb string with pdb, else assume connection is to cdb.
    #   - replace(connetion, cdb, pdb_name)
    #   db_unique_name or cdb#
    #    "Database System" = one(data.oci_database_database.ocidb_database_1).db_unique_name #,
    #        "Database System" = var.oci_db_pdb_service_name_1 #)


    db_options_0= {
        "Edit JDBC String" = trimspace(var.oci_db_connection_string_0) != var.ds_0 && length(trimspace(var.oci_db_connection_string_0)) >0 ? var.oci_db_connection_string_0 :"unchanged"
        "Autonomous Transaction Processing Database" = try(lookup(one(one(data.oci_database_autonomous_database.atp_db_0).connection_strings).all_connection_strings,upper(var.atp_db_level_0)),"none")
        "Database System" = trimspace(var.oci_db_pdb_service_name_0) !="" ? replace(try(lookup(one(one(data.oci_database_database.ocidb_database_0).connection_strings,"cdb_default")),"none"),one(data.oci_database_database.ocidb_database_0).db_unique_name,var.oci_db_pdb_service_name_0) :try(lookup(one(one(data.oci_database_database.ocidb_database_0).connection_strings,"cdb_default")),"none")
    }
    db_options_1= {
        "Edit JDBC String" = trimspace(var.oci_db_connection_string_1) != var.ds_1 && length(trimspace(var.oci_db_connection_string_1)) >0 ? var.oci_db_connection_string_1 :"unchanged"
        "Autonomous Transaction Processing Database" = try(lookup(one(one(data.oci_database_autonomous_database.atp_db_1).connection_strings).all_connection_strings,upper(var.atp_db_level_1)),"none")
        "Database System" = trimspace(var.oci_db_pdb_service_name_1) !="" ? replace(try(lookup(one(one(data.oci_database_database.ocidb_database_1).connection_strings,"cdb_default")),"none"),one(data.oci_database_database.ocidb_database_1).db_unique_name,var.oci_db_pdb_service_name_1) :try(lookup(one(one(data.oci_database_database.ocidb_database_1).connection_strings,"cdb_default")),"none")
    }

    #  "Database System"
    datasources = var.update_any_ds? {
    0 = {
            on_prem = var.ds_0
            oci = format("%s%s",local.jdbc_driver_thin_string,try(trimspace(local.db_options_0[var.db_strategy_0]),"empty"))
            is_atp = trimspace(var.atp_db_id_0) != ""
            is_oci_db = local.is_oci_db_0
            db_id = coalesce(var.atp_db_id_0, var.oci_db_dbsystem_id_0, "none")
            atp_db = local.atp_db_0
            oci_db = local.oci_db_0
            custom_jdbc = local.is_db_connection_string_0
            connection_string = var.oci_db_connection_string_0
        }
    1 = {
            on_prem = var.ds_1
            oci = format("%s%s",local.jdbc_driver_thin_string,try(trimspace(local.db_options_1[var.db_strategy_1]),"empty"))
            is_atp = trimspace(var.atp_db_id_1) != ""
            is_oci_db = local.is_oci_db_1
            db_id = coalesce(var.atp_db_id_1, var.oci_db_dbsystem_id_1, "none")
            atp_db = local.atp_db_1
            oci_db = local.oci_db_1
            custom_jdbc = local.is_db_connection_string_1
        }
    } : null
    }

# Database
locals {
    is_atp_db_0 = trimspace(var.atp_db_id_0) != ""
    is_atp_dedicated_0 = try(one(data.oci_database_autonomous_database.atp_db_0).is_dedicated,"none")
    is_atp_with_private_endpoints_0 = local.is_atp_db_0 && (length(data.oci_database_autonomous_database.atp_db_0) != 0 ? data.oci_database_autonomous_database.atp_db_0[0].subnet_id != null : false)
    atp_db_network_compartment_id_0 = local.is_atp_with_private_endpoints_0 && var.atp_db_network_compartment_id_0 == "" ? var.atp_db_compartment_id_0 : var.atp_db_network_compartment_id_0

    atp_db_0 = {
        atp_type                      = local.is_atp_dedicated_0
        #compartment_id                = var.atp_db_compartment_id_0
        is_atp_with_private_endpoints = local.is_atp_with_private_endpoints_0
        network_compartment_id        = local.atp_db_network_compartment_id_0
        # existing_vcn_id               = var.atp_db_existing_vcn_id_0
        #existing_vcn_add_seclist      = local.is_atp_with_private_endpoints_0 ? var.db_existing_vcn_add_secrule : false
        db_name                        = try(one(data.oci_database_autonomous_database.atp_db_0).db_name,"empty")
        db_level                       = var.atp_db_level_0
    }
    oci_db_0 = {
        is_oci_db                = local.is_oci_db_0
        #compartment_id           = local.oci_db_compartment_id_0
        network_compartment_id   = local.oci_db_network_compartment_id_0
        #    existing_vcn_id          = var.oci_db_existing_vcn_id
        #    existing_vcn_add_seclist = local.is_oci_db ? var.db_existing_vcn_add_secrule : false
    }

    is_oci_connection_string_0      = trimspace(var.oci_db_connection_string_0) == "" ? false : true
    #TODO Revisit network_compartment
    #  oci_db_compartment_id_0         = var.oci_db_compartment_id_0 == "" ? local.network_compartment_id_0 : var.oci_db_compartment_id_0
    #oci_db_compartment_id_0         = var.oci_db_compartment_id_0 == "" ? var.oci_db_compartment_id_0 : var.oci_db_compartment_id_0
    oci_db_network_compartment_id_0 = local.is_oci_db_0 && var.oci_db_network_compartment_id_0 == "" ? var.oci_db_compartment_id_0 : var.oci_db_network_compartment_id_0
    db_network_compartment_id_0 = local.is_atp_with_private_endpoints_0 ? local.atp_db_network_compartment_id_0 : local.oci_db_network_compartment_id_0

    #OCI DB
    is_oci_db_0                    = (trimspace(var.oci_db_dbsystem_id_0) != "") ? true : false
    is_db_connection_string_0 = trimspace(var.ds_0) != trimspace(var.oci_db_connection_string_0) ? true : false
    is_ocidb_system_id_available_0 = trimspace(var.oci_db_dbsystem_id_0) != ""

    is_atp_db_1 = trimspace(var.atp_db_id_1) != ""
    is_atp_dedicated_1 = try(one(data.oci_database_autonomous_database.atp_db_1).is_dedicated,"none")
    is_atp_with_private_endpoints_1 = local.is_atp_db_1 && (length(data.oci_database_autonomous_database.atp_db_1) != 0 ? data.oci_database_autonomous_database.atp_db_1[0].subnet_id != null : false)
    atp_db_network_compartment_id_1 = local.is_atp_with_private_endpoints_1 && var.atp_db_network_compartment_id_1 == "" ? var.atp_db_compartment_id_1 : var.atp_db_network_compartment_id_1

    atp_db_1 = {
        atp_type                      = local.is_atp_dedicated_1
        #compartment_id                = var.atp_db_compartment_id_1
        is_atp_with_private_endpoints = local.is_atp_with_private_endpoints_1
        network_compartment_id        = local.atp_db_network_compartment_id_1
        # existing_vcn_id               = var.atp_db_existing_vcn_id_1
        #existing_vcn_add_seclist      = local.is_atp_with_private_endpoints_1 ? var.db_existing_vcn_add_secrule : false
        db_name                        = try(one(data.oci_database_autonomous_database.atp_db_1).db_name,"empty")
        db_level                       = var.atp_db_level_1
    }
    oci_db_1 = {
        is_oci_db                = local.is_oci_db_1
        #compartment_id           = local.oci_db_compartment_id_1
        network_compartment_id   = local.oci_db_network_compartment_id_1
        #    existing_vcn_id          = var.oci_db_existing_vcn_id
        #    existing_vcn_add_seclist = local.is_oci_db ? var.db_existing_vcn_add_secrule : false
    }

    is_oci_connection_string_1      = trimspace(var.oci_db_connection_string_1) == "" ? false : true
    #TODO Revisit network_compartment
    #  oci_db_compartment_id_1         = var.oci_db_compartment_id_1 == "" ? local.network_compartment_id_1 : var.oci_db_compartment_id_1
    #oci_db_compartment_id_1         = var.oci_db_compartment_id_1 == "" ? var.oci_db_compartment_id_1 : var.oci_db_compartment_id_1
    oci_db_network_compartment_id_1 = local.is_oci_db_1 && var.oci_db_network_compartment_id_1 == "" ? var.oci_db_compartment_id_1 : var.oci_db_network_compartment_id_1
    db_network_compartment_id_1 = local.is_atp_with_private_endpoints_1 ? local.atp_db_network_compartment_id_1 : local.oci_db_network_compartment_id_1

    #OCI DB
    is_oci_db_1                    = (trimspace(var.oci_db_dbsystem_id_1) != "") ? true : false
    is_db_connection_string_1 = trimspace(var.ds_1) != trimspace(var.oci_db_connection_string_1) ? true : false
    is_ocidb_system_id_available_1 = trimspace(var.oci_db_dbsystem_id_1) != ""

}


