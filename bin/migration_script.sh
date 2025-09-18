#!/usr/bin/env bash
# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

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
  # Executes the specified migration step
  # arg1: step name.
  # arg2: script command.
  # arg3: (Optional) Allow exit code 1 to pass (Used in the case of WDT).(default: false).
  # arg4: (Optional) json key for the metadata (migration_data.json) file. (default: ${step_name}_status).
  # arg5: (Optional) returns the exit code if set to true. (default: false).
  # arg6: (Optional) soft fail - do not stop script on failure. (default: false).

  local step_name="$1"
  local script_cmd="$2"
  local allow_exit_code_1="${3:-false}"
  local json_key="${4:-${step_name}_status}"
  local return_exit_code="${5:-false}"
  local soft_fail="${6:-false}"

  # Skip if already marked as success, continues otherwise.
  local status=""
  status=$(python3 "$toolHome/lib/python/json_utils.py" get_optional_key "$MIGRATION_DATA_JSON" "$json_key")
  if [ "$status" = "success" ]; then
    log "info" "\"$step_name\" already completed successfully. Skipping."
    if [ "$return_exit_code" = "true" ]; then
        RETURN_STATUS=0
    fi
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

    if [ "$return_exit_code" = "true" ]; then
      RETURN_STATUS=$exit_code
      return 0
    fi

  else
    update_migration_data_json "$json_key" "failed"

    if [ "$soft_fail" = "true" ]; then
      log "warning" "\"$step_name\" failed (non-blocking). Check $MIGRATION_SCRIPT_LOG for details."
      if [ "$return_exit_code" = "true" ]; then
        RETURN_STATUS=$exit_code
        return 0
      fi
      return 0
    fi

    log "error" "\"$step_name\" failed. Check $MIGRATION_SCRIPT_LOG for details. Run migration_script.sh again after resolving the issue."

    if [ "$return_exit_code" = "true" ]; then
      RETURN_STATUS=$exit_code
      return 0
    fi

    log "error" "Migration failed."
    exit $exit_code
  fi

  echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
}

get_json_key() {
  local file_path="$1"
  local key="$2"
  local value
  local output

  # Capture both stdout and stderr
  output=$(python3 "$toolHome/lib/python/json_utils.py" read_key "$file_path" "$key" 2>&1)
  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log "error" "Failed to extract key '$key' from JSON file '$file_path': $output. See $MIGRATION_SCRIPT_LOG for details."
    return $exit_code
  fi

  echo "$output"
}

upload_stack_to_oci_func() {
  result=$(python3 -c "import sys, json; sys.path.insert(0, '../lib/python'); \
from upload_stack_to_oci import upload_stack_zip_to_oci; \
code, par_url = upload_stack_zip_to_oci('$STACK_FILE', '$bucket_name', '$tenancy_namespace', '$compartment_ocid', '$MIGRATION_SCRIPT_LOG', '$(date +%s)'); \
print(json.dumps({'code': code, 'par_url': par_url})); \
sys.exit(code)")

  exit_code=$?
  # Extract PAR_URL if JSON is valid
  if [ "$exit_code" -eq 0 ]; then
    PAR_URL=$(echo "$result" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('par_url') or '')")
    export PAR_URL
  else
    PAR_URL=""
  fi

  return $exit_code
}

########################################## SECTION : Install Dependencies ###################################################
run_migration_step  "Installing dependencies" "bash \"$MIGRATION_SCRIPT_DIR/install_dependencies.sh\"" "" "install_dependencies"

########################################## SECTION : Prerequisites check ####################################################
run_migration_step "Checking prerequisites" "bash \"$MIGRATION_SCRIPT_DIR/check_pre-reqs.sh\"" "" "prerequisites_check"

########################################## SECTION : MIGRATION ##############################################################

########################################## SUB_SECTION : Discover Weblogic Domain ###########################################
run_migration_step "Discovering WebLogic domain" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" wls" "true" "wls_discover"

if ! WLS_JSON=$(get_json_key "$MIGRATION_DATA_JSON" "wls_json"); then
  log "error" "Failed to get the json key :WLS_JSON, cannot proceed."
  log "error" "Migration failed."
  exit 1
fi
echo "WLS file created: $WLS_JSON" >> "$MIGRATION_SCRIPT_LOG"

########################################## SUB_SECTION : Discover Infrastructure ############################################
run_migration_step "Discovering infrastructure" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" infra $WLS_JSON" "true" "infra_discover"

if ! INFRA_JSON=$(get_json_key "$MIGRATION_DATA_JSON" "infra_json"); then
  log "error" "Failed to get the json key :INFRA_JSON, cannot proceed."
  log "error" "Migration failed."
  exit 1
fi
echo "INFRA file created: $INFRA_JSON" >> "$MIGRATION_SCRIPT_LOG"

##################################### SUB_SECTION : Discovery Database Connections ##########################################
run_migration_step "Discovering datasources" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" ds $INFRA_JSON" "true" "discover_datasources"

##################################### SUB_SECTION :  Generate OCI Resource Manager Stacks ###################################
run_migration_step "Building OCI Resource Manager stack" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" orm $INFRA_JSON" "" "build_oci_orm"

if ! STACK_FILE=$(get_json_key "$MIGRATION_DATA_JSON" "stack_file"); then
  log "error" "Failed to get the json key :STACK_FILE, cannot proceed."
  log "error" "Migration failed."
  exit 1
fi

log "info" "Stack file created: $STACK_FILE"

##################################### SUB_SECTION : Upload OCI Resource Manager Stack to OCI ################################
if [[ "$skip_transfer" = "false" ]]; then
	  stack_filename=$(basename "$STACK_FILE")
    run_migration_step "Uploading $stack_filename to OCI Object Storage bucket $bucket_name" "upload_stack_to_oci_func" "" "upload_stack_to_oci" "true" "true"

    upload_exit_code=$RETURN_STATUS
    if [ "$upload_exit_code" -eq 0 ]; then
        log "info" "$stack_filename uploaded to bucket $bucket_name."
        if [[ -n "$PAR_URL" ]]; then
            log "info" "Generated PAR URL (valid 6 months): $PAR_URL"
        fi
    fi
else
    log "info" "Skipping $stack_filename upload as skip_transfer=$skip_transfer."
fi


########################################## SUB_SECTION : Archive Weblogic Domain ############################################

# Skipping the transfer
if [ "$skip_transfer" = "true" ]; then

  run_migration_step "Archiving WebLogic domain" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" archive $INFRA_JSON" "" "archive_weblogic_domain" "true"
  exit_code=$RETURN_STATUS

  log "info" "Skipping the transfer archives to OCI Object Storage step as  [skip_transfer] : \"$skip_transfer\". Transfer the archives manually by following the instruction in $MIGRATION_SCRIPT_LOG ."
  echo "The restore process expects all of the archives to be stored in a Oracle Cloud Object Storage Bucket. Follow Oracle Cloud documentation on how to transfer files via the Oracle Cloud Console. You can use OCI CLI to create an object store bucket and upload the archives to it.  More information at :
        https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
        https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets_topic-To_create_a_bucket.htm#top
        https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingobjects_topic-To_upload_objects_to_a_bucket.htm" >> "$MIGRATION_SCRIPT_LOG"
  update_migration_data_json "upload_to_oci" "skipped"

  if [ $exit_code -ne 0 ]; then
    log "error" "Migration script failed."
    exit $exit_code
  fi
fi

##################################### SUB_SECTION : Upload Archives to OCI Object Storage (Optional) ########################

if [ "$skip_transfer" = "false" ]; then
  run_migration_step "Archiving WebLogic domain" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" archive $INFRA_JSON" "" "archive_weblogic_domain"
fi

#############################################################################################################################
log "info" "Migration script completed successfully!"
