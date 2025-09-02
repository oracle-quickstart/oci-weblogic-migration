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
file_timestamp="$(date +"%Y%m%d")_$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
upload_log_file="$toolHome/logs/upload_unzipped_stack_to_oci_${file_timestamp}.log"
LOG_FILE_NAME="migration_script.log"
MIGRATION_SCRIPT_LOG="$toolHome/logs/$LOG_FILE_NAME"
MIGRATION_DATA_JSON="$toolHome/logs/migration_data.json"
ON_PREM_ENV_FILE="$toolHome/config/on-prem.env"


[ "$user_functions_loaded" ] || source "$toolHome/bin/shared.sh"
load_config "$ON_PREM_ENV_FILE" > /dev/null 2>&1

run_migration_step() {

  #Executes the specified migration step
  #arg1: step name.
  #arg2: script command.
  #arg3: (Optional) Allow exit code 1 to pass (Used in the case of WDT).(default : false).
  #arg4: (Optional) json key for the metadata (migration_data.json) file. (default: $(step_name)_status).
  #arg5: (Optional) returns the exit code if set to true. (default : false).

  local step_name="$1"
  local script_cmd="$2"
  local allow_exit_code_1="${3:-false}"
  local json_key="${4:-${step_name}_status}"
  local return_exit_code="${5:-false}"

  # Skip if already marked as success, continues otherwise.
  local status=""
  status=$(python3 "$toolHome/lib/python/json_utils.py" get_optional_key "$MIGRATION_DATA_JSON" "$json_key")
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

    if [ "$return_exit_code" = "true" ]; then
      RETURN_STATUS=$exit_code
      return 0
    fi

  else
    update_migration_data_json "$json_key" "failed"
    log "error" " \"$step_name\" failed. Check $MIGRATION_SCRIPT_LOG for details. Run migration_script.sh again after resolving the issue."

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

upload_unzipped_stack_to_oci() {
  local stack_zip="$1"
  local bucket_name="$2"
  local namespace="$3"
  local compartment_id="$4"
  local temp_dir="/tmp/stack_upload_$file_timestamp"

  if [[ ! -f "$stack_zip" ]]; then
    log "error" "Stack zip file not found: $stack_zip" | tee -a "$upload_log_file" >&2
    exit 1
  fi

  # Check if bucket exists
  log "info" "Checking if bucket $bucket_name exists in namespace $namespace..." >> "$upload_log_file"
  bucket_exists=$(oci os bucket list \
      --namespace-name "$namespace" \
      --compartment-id "$compartment_id" \
      --query "data[?name=='$bucket_name'] | length(@)" \
      --raw-output)
  # If bucket does not exist, create it
  if [[ "$bucket_exists" -eq 0 ]]; then
      log "info" "Bucket $bucket_name not found. Creating..." >> "$upload_log_file"
      oci os bucket create \
          --namespace-name "$namespace" \
          --name "$bucket_name" \
          --compartment-id "$compartment_id" >> "$upload_log_file" 2>&1
      log "info" "Bucket $bucket_name created." >> "$upload_log_file"
  else
      log "info" "Bucket $bucket_name already exists." >> "$upload_log_file"
  fi

  # Prepare temp dir & unzip
  mkdir $temp_dir
  log "info" "Unzipping stack: $stack_zip to $temp_dir" >> "$upload_log_file"
  unzip -q "$stack_zip" -d "$temp_dir" >> "$upload_log_file" 2>&1

  # Upload to OCI
  log "info" "Uploading unzipped stack to OCI bucket... " | tee -a "$upload_log_file"
  oci os object bulk-upload \
      --bucket-name "$bucket_name" \
      --namespace-name "$namespace" \
      --src-dir "$temp_dir" \
      --prefix "$file_timestamp/" \
      --overwrite >> "$upload_log_file" 2>&1
  exit_code=$?
  return $exit_code

  # Cleanup temp dir
  rm -rf "$temp_dir"
  log "info" "Temporary directory $temp_dir removed." >> "$upload_log_file"
  echo "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------" >> "$MIGRATION_SCRIPT_LOG"
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
if [ "$skip_transfer" = "false" ] && [ -n "$STACK_FILE" ] ; then
    if [[ -n "$bucket_name" && -n "$tenancy_namespace" && -n "$compartment_ocid" ]]; then
       upload_unzipped_stack_to_oci "$STACK_FILE" "$bucket_name" "$tenancy_namespace" "$compartment_ocid"
       if [ "$exit_code" == 0 ]; then
          log "info" "Stack files are uploaded to bucket $bucket_name inside folder: $file_timestamp" | tee -a "$upload_log_file"
       else
          log "warning" "Stack upload to bucket failed. Check for errors in file: $upload_log_file" | tee -a "$upload_log_file"
       fi
    else
       log "warning" "bucket_name, tenancy_namespace, or compartment_ocid not set in $ON_PREM_ENV_FILE. Skipping stack upload to OCI bucket." | tee -a "$upload_log_file"
    fi
fi

########################################## SUB_SECTION : Archive Weblogic Domain ############################################

# Invalid condition: Cannot skip archive but still try to transfer
if [ "$skip_archive" = "true" ] && [ "$skip_transfer" = "false" ]; then
  log "warning" "Invalid configuration: skip_archive is set to true, but skip_transfer is false. Cannot transfer archives that were not created."
  log "info"  "Either create the archives manually and proceed with transfer."
  echo "To manually perform the archive step, navigate to the bin directory and execute the following command:
    | bash owm.sh archive $INFRA_JSON -skip_archive |
    Then follow the instructions provided in the terminal output (look for TODO messages)." >> "$MIGRATION_SCRIPT_LOG"
  echo "The restore process expects all of the archives to be stored in a Oracle Cloud Object Storage Bucket. Follow Oracle Cloud documentation on how to transfer files via the Oracle Cloud Console. You can use OCI CLI to create an object store bucket and upload the archives to it.  More information at :
          https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
          https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets_topic-To_create_a_bucket.htm#top
          https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingobjects_topic-To_upload_objects_to_a_bucket.htm" >> "$MIGRATION_SCRIPT_LOG"
  update_migration_data_json "archive_weblogic_domain" "skipped"
  update_migration_data_json "upload_to_oci" "skipped"
  exit 1
fi

# Skipping the archive and lift.
if [ "$skip_archive" = "true" ] && [ "$skip_transfer" = "true" ]; then
  log "info" "Skipping the Archive Weblogic Domain and the transfer archives to OCI Object Storage step as [skip_archive] : \"$skip_archive\" | [skip_transfer] : \"$skip_transfer\". Create the archives manually by following the instruction in $MIGRATION_SCRIPT_LOG ."
  echo "To manually perform the archive step, navigate to the bin directory and execute the following command:
    | bash owm.sh archive $INFRA_JSON -skip_archive |
    Then follow the instructions provided in the terminal output (look for TODO messages)." >> "$MIGRATION_SCRIPT_LOG"
  echo "The restore process expects all of the archives to be stored in a Oracle Cloud Object Storage Bucket. Follow Oracle Cloud documentation on how to transfer files via the Oracle Cloud Console. You can use OCI CLI to create an object store bucket and upload the archives to it.  More information at :
        https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
        https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets_topic-To_create_a_bucket.htm#top
        https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingobjects_topic-To_upload_objects_to_a_bucket.htm" >> "$MIGRATION_SCRIPT_LOG"
  update_migration_data_json "archive_weblogic_domain" "skipped"
  update_migration_data_json "upload_to_oci" "skipped"
  exit 1
fi


# Skipping the transfer
if [ "$skip_archive" = "false" ] && [ "$skip_transfer" = "true" ]; then

  run_migration_step "Archiving WebLogic domain" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" archive $INFRA_JSON" "" "archive_weblogic_domain" "true"
  exit_code=$RETURN_STATUS

  log "info" "Skipping the transfer archives to OCI Object Storage step as  [skip_transfer] : \"$skip_transfer\". Transfer the archives manually by following the instruction in $MIGRATION_SCRIPT_LOG ."
  echo "The restore process expects all of the archives to be stored in a Oracle Cloud Object Storage Bucket. Follow Oracle Cloud documentation on how to transfer files via the Oracle Cloud Console. You can use OCI CLI to create an object store bucket and upload the archives to it.  More information at :
        https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm
        https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets_topic-To_create_a_bucket.htm#top
        https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingobjects_topic-To_upload_objects_to_a_bucket.htm" >> "$MIGRATION_SCRIPT_LOG"
  update_migration_data_json "upload_to_oci" "skipped"

  if [ $exit_code -ne 0 ]; then
    log "error" "Migration failed."
    exit $exit_code
  fi
fi

##################################### SUB_SECTION : Upload Archives to OCI Object Storage (Optional) ########################

if [ "$skip_archive" = "false" ] && [ "$skip_transfer" = "false" ]; then
  run_migration_step "Archiving WebLogic domain" "bash \"$MIGRATION_SCRIPT_DIR/owm.sh\" archive $INFRA_JSON" "" "archive_weblogic_domain"
fi

#############################################################################################################################
log "info" "Migration scripts completed successfully!"
