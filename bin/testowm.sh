#!/usr/bin/env bash
# Copyright (c) 2024, 2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : testowm.sh
# Description          : Consolidated script to run the entire migration process
#############################################################################################################################

TESTOWM_SCRIPT_DIR="$(dirname "$0")"

########################################## SECTION : Install Dependencies ###################################################
#Downloading and installing all dependencies
bash "$TESTOWM_SCRIPT_DIR/install_dependencies.sh"

if [ $? -ne 0 ]; then
  echo "Failed to install dependencies."
  exit 1
fi

#############################################################################################################################

########################################## SECTION : Prerequisites check ####################################################
bash "$TESTOWM_SCRIPT_DIR/check_pre-reqs.sh"

if [ $? -ne 0 ]; then
  echo "Failed in prerequisites check."
  exit 1
fi
#############################################################################################################################

########################################## SECTION : MIGRATION ##############################################################
source "$TESTOWM_SCRIPT_DIR/owm.sh"
load_config "$2"

########################################## SUB_SECTION : Discover Weblogic Domain ###########################################
discover_local
if [ $? -ne 0 ]; then
  echo "Discover Weblogic failed."
  exit 1
fi
#############################################################################################################################

########################################## SUB_SECTION : Discover Infrastructure ############################################
discover_infra_local $DISCOVERED_DOMAIN_JSON

if [ $? -ne 0 ]; then
  echo "Discover infra failed."
  exit 1
fi
#############################################################################################################################

########################################## SUB_SECTION : Archive Weblogic Domain ############################################
process_archives $DISCOVERED_INFRA_JSON

if [ $? -ne 0 ]; then
  echo "Archive Weblogic Domain failed."
  exit 1
fi
#############################################################################################################################

##################################### SUB_SECTION : Upload Archives to OCI Object Storage (Optional) ########################
upload_to_oci $DISCOVERED_INFRA_JSON "../out"

if [ $? -ne 0 ]; then
  echo "Failed to lift the archive files."
  exit 1
fi
#############################################################################################################################

##################################### SUB_SECTION : Discovery Database Connections ##########################################
process_datasources $DISCOVERED_INFRA_JSON

if [ $? -ne 0 ]; then
  echo "Failed to discover datasources."
  exit 1
fi
#############################################################################################################################

##################################### SUB_SECTION :  Generate OCI Resource Manager Stacks ###################################
build_orm $DISCOVERED_INFRA_JSON

if [ $? -ne 0 ]; then
  echo "Failed to build the orm bundle."
  exit 1
fi
#############################################################################################################################
