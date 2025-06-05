#!/usr/bin/env bash
# Copyright (c) 2024, 2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : migration_script.sh
# Description          : Consolidated script to run the entire migration process.
#############################################################################################################################

TESTOWM_SCRIPT_DIR="$(dirname "$0")"
source "$TESTOWM_SCRIPT_DIR/owm.sh"

mkdir -p "$toolHome/logs/"
CONSOLIDATED_LOG_FILE="$toolHome/logs/migration_script.log"

########################################## SECTION : Install Dependencies ###################################################
log "info" "Installing Dependencies.." | tee -a "$CONSOLIDATED_LOG_FILE"

set +e
bash "$TESTOWM_SCRIPT_DIR/install_dependencies.sh" >> "$CONSOLIDATED_LOG_FILE" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed at install dependencies. Errors can be found in $CONSOLIDATED_LOG_FILE"
  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
  exit 1
fi

log "info" "Successfully installed dependencies." >> "$CONSOLIDATED_LOG_FILE"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
#############################################################################################################################

########################################## SECTION : Prerequisites check ####################################################
#log "info" "Checking prerequisites.." | tee -a "$CONSOLIDATED_LOG_FILE"
#
#set +e
#bash "$TESTOWM_SCRIPT_DIR/check_pre-reqs.sh" >> "$CONSOLIDATED_LOG_FILE" 2>&1
#process_exit_code=$?
#set -e
#
#if [ "$process_exit_code" -ne 0 ]; then
#  log "error" "Script execution failed at prerequisites check. Errors can be found in $CONSOLIDATED_LOG_FILE"
#  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
#  exit 1
#fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
#############################################################################################################################

########################################## SECTION : MIGRATION ##############################################################

set +e
load_config "$ON_PREM_ENV_FILE/on-prem.env" >> "$CONSOLIDATED_LOG_FILE" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in loading configuration file. Errors can be found in $CONSOLIDATED_LOG_FILE"
  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
########################################## SUB_SECTION : Discover Weblogic Domain ###########################################
log "info" "Discovering WebLogic domain.." | tee -a "$CONSOLIDATED_LOG_FILE"

set +e
bash owm.sh wls ../config/on-prem.env >> "$CONSOLIDATED_LOG_FILE" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in discovering WebLogic domain. Errors can be found in $CONSOLIDATED_LOG_FILE"
  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
#############################################################################################################################

########################################## SUB_SECTION : Discover Infrastructure ############################################
log "info" "Discovering infrastructure.." | tee -a "$CONSOLIDATED_LOG_FILE"

set +e
bash owm.sh infra ../config/on-prem.env $DISCOVERED_DOMAIN_JSON >> "$CONSOLIDATED_LOG_FILE" 2>&1
#discover_infra_local "$DISCOVERED_DOMAIN_JSON" >> "$CONSOLIDATED_LOG_FILE" 2>&1
process_exit_code=$?
set -e
echo "exit code : $process_exit_code"
if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in discovering infrastructure. Errors can be found in $CONSOLIDATED_LOG_FILE"
  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
  exit 1
fi


echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
#############################################################################################################################

########################################## SUB_SECTION : Archive Weblogic Domain ############################################
log "info" "Archiving WebLogic domain.." | tee -a "$CONSOLIDATED_LOG_FILE"

set +e
process_archives $DISCOVERED_INFRA_JSON >> "$CONSOLIDATED_LOG_FILE" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in archiiving Weblogic domain. Errors can be found in $CONSOLIDATED_LOG_FILE"
  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
#############################################################################################################################

##################################### SUB_SECTION : Upload Archives to OCI Object Storage (Optional) ########################
log "info" "Uploading archives to OCI.." | tee -a "$CONSOLIDATED_LOG_FILE"

set +e
upload_to_oci $DISCOVERED_INFRA_JSON "../out" >> "$CONSOLIDATED_LOG_FILE" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in uploading archives to OCI Object Storage. Errors can be found in $CONSOLIDATED_LOG_FILE"
  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
#############################################################################################################################

##################################### SUB_SECTION : Discovery Database Connections ##########################################
log "info" "Discovering datasources.." | tee -a "$CONSOLIDATED_LOG_FILE"

set +e
process_datasources $DISCOVERED_INFRA_JSON >> "$CONSOLIDATED_LOG_FILE" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in Discovery Database Connections. Errors can be found in $CONSOLIDATED_LOG_FILE"
  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
#############################################################################################################################

##################################### SUB_SECTION :  Generate OCI Resource Manager Stacks ###################################
log "info" "Building OCI Resource Manager stack.." | tee -a "$CONSOLIDATED_LOG_FILE"
set +e
build_orm $DISCOVERED_INFRA_JSON >> "$CONSOLIDATED_LOG_FILE" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in building OCI Resource Manager stack. Errors can be found in $CONSOLIDATED_LOG_FILE"
  log "error" "Migration failed." | tee -a "$CONSOLIDATED_LOG_FILE"
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$CONSOLIDATED_LOG_FILE"
#############################################################################################################################
log "info" "Migration completed successfully!" | tee -a "$CONSOLIDATED_LOG_FILE"
log "info" "Stack file created: ${toolHome}/oci/stack/$STACK_NAME.zip" | tee -a "$CONSOLIDATED_LOG_FILE"