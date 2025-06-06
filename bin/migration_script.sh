#!/usr/bin/env bash
# Copyright (c) 2024, 2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : migration_script.sh
# Description          : Consolidated script to run the entire migration process.
#############################################################################################################################

MIGRATION_SCRIPT_DIR="$(dirname "$0")"
toolHome=$(builtin cd "$MIGRATION_SCRIPT_DIR/.." ||exit; pwd)
mkdir -p "$toolHome/logs/"
LOG_FILE_NAME="migration_script.log"
MIGRATION_SCRIPT_LOG="$toolHome/logs/$LOG_FILE_NAME"
MIGRATION_DATA_JSON="$toolHome/logs/migration_data.json"

[ "$user_functions_loaded" ] || source "$toolHome/bin/shared.sh"

########################################## SECTION : Install Dependencies ###################################################
log "info" "Installing Dependencies.."

set +e
bash "$MIGRATION_SCRIPT_DIR/install_dependencies.sh" >> "$MIGRATION_SCRIPT_LOG" 2>&1
process_exit_code=$?
set -e
if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed at install dependencies. Errors can be found in $MIGRATION_SCRIPT_LOG"
  log "error" "Migration failed."
  exit 1
fi

log "info" "Successfully installed dependencies." >> "$MIGRATION_SCRIPT_LOG"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
#############################################################################################################################

########################################## SECTION : Prerequisites check ####################################################
log "info" "Checking prerequisites.."

set +e
bash "$MIGRATION_SCRIPT_DIR/check_pre-reqs.sh" >> "$MIGRATION_SCRIPT_LOG" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed at prerequisites check. Errors can be found in $MIGRATION_SCRIPT_LOG"
  log "error" "Migration failed."
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
#############################################################################################################################

########################################## SECTION : MIGRATION ##############################################################

########################################## SUB_SECTION : Discover Weblogic Domain ###########################################
log "info" "Discovering WebLogic domain.."

set +e
bash owm.sh wls ../config/on-prem.env >> "$MIGRATION_SCRIPT_LOG" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in discovering WebLogic domain. Errors can be found in $MIGRATION_SCRIPT_LOG"
  log "error" "Migration failed."
  exit 1
fi

WLS_JSON=$(jq -r '.wls_json' "$MIGRATION_DATA_JSON")

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
#############################################################################################################################

########################################## SUB_SECTION : Discover Infrastructure ############################################
log "info" "Discovering infrastructure.."

set +e
bash owm.sh infra $WLS_JSON >> "$MIGRATION_SCRIPT_LOG" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in discovering infrastructure. Errors can be found in $MIGRATION_SCRIPT_LOG"
  log "error" "Migration failed."
  exit 1
fi

INFRA_JSON=$(jq -r '.infra_json' "$MIGRATION_DATA_JSON")

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
#############################################################################################################################

########################################## SUB_SECTION : Archive Weblogic Domain ############################################
log "info" "Archiving WebLogic domain.."

set +e
bash owm.sh archive $INFRA_JSON >> "$MIGRATION_SCRIPT_LOG" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in archiiving Weblogic domain. Errors can be found in $MIGRATION_SCRIPT_LOG"
  log "error" "Migration failed."
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
#############################################################################################################################

##################################### SUB_SECTION : Upload Archives to OCI Object Storage (Optional) ########################
log "info" "Uploading archives to OCI.."

set +e
bash owm.sh lift $INFRA_JSON ../out >> "$MIGRATION_SCRIPT_LOG" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in uploading archives to OCI Object Storage. Errors can be found in $MIGRATION_SCRIPT_LOG"
  log "error" "Migration failed."
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
#############################################################################################################################

##################################### SUB_SECTION : Discovery Database Connections ##########################################
log "info" "Discovering datasources.."

set +e
bash owm.sh ds $INFRA_JSON >> "$MIGRATION_SCRIPT_LOG" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in Discovery Database Connections. Errors can be found in $MIGRATION_SCRIPT_LOG"
  log "error" "Migration failed."
  exit 1
fi

echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
#############################################################################################################################

##################################### SUB_SECTION :  Generate OCI Resource Manager Stacks ###################################
log "info" "Building OCI Resource Manager stack.."
set +e
bash owm.sh orm $INFRA_JSON >> "$MIGRATION_SCRIPT_LOG" 2>&1
process_exit_code=$?
set -e

if [ "$process_exit_code" -ne 0 ]; then
  log "error" "Script execution failed in building OCI Resource Manager stack. Errors can be found in $MIGRATION_SCRIPT_LOG"
  log "error" "Migration failed."
  exit 1
fi
STACK_FILE=$(jq -r '.stack_file' "$MIGRATION_DATA_JSON")
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
#############################################################################################################################
log "info" "Migration completed successfully!"
log "info" "Stack file created: $STACK_FILE"