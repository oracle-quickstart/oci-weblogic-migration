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
ON_PREM_ENV_FILE="$toolHome/config/on-prem.env"


[ "$user_functions_loaded" ] || source "$toolHome/bin/shared.sh"
load_config "$ON_PREM_ENV_FILE" > /dev/null 2>&1

run_migration_step() {

  #Runs the specified migration step
  #arg1: step name.
  #arg2: script command.
  #arg3: (Optional) Allow exit code 1 to pass (Used in the case of WDT).(default : false).
  #arg4: (Optional) json key for the medata (migration_data.json) file. (default: $(step_name)_status).

  local step_name="$1"
  local script_cmd="$2"
  local allow_exit_code_1="${3:-false}"
  local json_key="${4:-${step_name}_status}"

  # Skip if already marked as success, continues otherwise.
  local status=""
  [ -f "$MIGRATION_DATA_JSON" ] && status=$(jq -r --arg k "$json_key" '.[$k] // empty' "$MIGRATION_DATA_JSON")
  if [ "$status" = "success" ]; then
    log "info" "\"$step_name\" already completed successfully. Skipping."
    return
  fi

  log "info" "$step_name..."
  update_migration_data_json "$json_key" "in_progress"

  set +e
  eval "$script_cmd" >> "$MIGRATION_SCRIPT_LOG" 2>&1
  local exit_code=$?
  set -e

  if [ "$exit_code" -eq 0 ] || { [ "$allow_exit_code_1" = "true" ] && [ "$exit_code" -eq 1 ]; }; then
    update_migration_data_json "$json_key" "success"
  else
    update_migration_data_json "$json_key" "failed"
    log "error" " \"$step_name\" failed. Check $MIGRATION_SCRIPT_LOG for details. Run migration_script.sh again after resolving the issue."
    log "error" "Migration failed."
    exit $exit_code
  fi

  echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
}

########################################## SECTION : Install Dependencies ###################################################
run_migration_step  "Installing dependencies" "bash \"$MIGRATION_SCRIPT_DIR/install_dependencies.sh\"" "" "install_dependencies"

########################################## SECTION : Prerequisites check ####################################################
run_migration_step "Checking prerequisites" "bash \"$MIGRATION_SCRIPT_DIR/check_pre-reqs.sh\"" "" "prerequisites_check"

########################################## SECTION : MIGRATION ##############################################################

########################################## SUB_SECTION : Discover Weblogic Domain ###########################################
run_migration_step "Discovering WebLogic domain" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" wls" "true" "wls_discover"
WLS_JSON=$(jq -r '.wls_json' "$MIGRATION_DATA_JSON")

########################################## SUB_SECTION : Discover Infrastructure ############################################
run_migration_step "Discovering infrastructure" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" infra $WLS_JSON" "true" "infra_discover"
INFRA_JSON=$(jq -r '.infra_json' "$MIGRATION_DATA_JSON")

##################################### SUB_SECTION : Discovery Database Connections ##########################################
run_migration_step "Discovering datasources" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" ds $INFRA_JSON" "true" "discover_datasources"

##################################### SUB_SECTION :  Generate OCI Resource Manager Stacks ###################################
run_migration_step "Building OCI Resource Manager stack" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" orm $INFRA_JSON" "" "build_oci_orm"
STACK_FILE=$(jq -r '.stack_file' "$MIGRATION_DATA_JSON")
log "info" "Stack file created: $STACK_FILE"

########################################## SUB_SECTION : Archive Weblogic Domain ############################################

if [ "$skip_archive" = "true" ]; then
  log "info" "Skipping the Archive Weblogic Domain step as [skip_archive] : \"$skip_archive\". Create the archives manually by following the instruction in $MIGRATION_SCRIPT_LOG"
  echo "To manually perform the archive step, navigate to the bin directory and execute the following command:
  | bash owm.sh archive $INFRA_JSON -skip_archive |
  Then follow the instructions provided in the terminal output (look for TODO messages)." >> "$MIGRATION_SCRIPT_LOG"
  update_migration_data_json "archive_weblogic_domain" "skipped"
  update_migration_data_json "upload_to_oci" "skipped"
else
  run_migration_step "Archiving WebLogic domain" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" archive $INFRA_JSON" "true" "archive_weblogic_domain"
fi

##################################### SUB_SECTION : Upload Archives to OCI Object Storage (Optional) ########################

if [ "$skip_archive" = "true" ] || [ "$skip_transfer" = "true" ]; then
  log "info" "Skipping the transfer archives to OCI Object Storage step as [skip_archive] : \"$skip_archive\" | [skip_transfer] : \"$skip_transfer\". Transfer the archives manually by following the instruction in $MIGRATION_SCRIPT_LOG."
  echo "The restore process expects all of the archives to be stored in a Oracle Cloud Object Storage Bucket. Follow Oracle Cloud documentation on how to transfer files via the Oracle Cloud Console. You can use OCI CLI to create an object store bucket and upload the archives to it.  More information at :
        https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
        https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets_topic-To_create_a_bucket.htm#top
        https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingobjects_topic-To_upload_objects_to_a_bucket.htm" >> "$MIGRATION_SCRIPT_LOG"
  update_migration_data_json "upload_to_oci" "skipped"
else
  run_migration_step "Uploading archives to OCI" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" lift $INFRA_JSON ../out" "" "upload_to_oci"
fi

#############################################################################################################################
log "info" "Migration scripts completed successfully!"
