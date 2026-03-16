#!/usr/bin/env bash

# Copyright (c) 2025, 2026, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

#############################################################################################################################
# Name                 : owm.sh
# Description          : Discovers a Weblogic Domain Environment and moves it to Oracle Cloud.
#############################################################################################################################
scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.." ||exit; pwd)
LOG_FILE_NAME="owm.log"
ON_PREM_ENV_FILE="$toolHome/config/on-prem.env"

[ "$user_functions_loaded" ] || source "$scriptPath/shared.sh"


discover(){
  log "info" "<discoverDomain><discover><entry> args: $*"
  EXEC_TYPE=$1
  SCRIPT_PATH=$2
  shift; shift
  DISCOVER_BASE_FLAGS="-oracle_home $oracle_home  $*"
  if [[ "$EXEC_TYPE" == "remote" ]]; then
      run_ssh_command "$SCRIPT_PATH" "$DISCOVER_BASE_FLAGS"
  else
     bash "$SCRIPT_PATH" $DISCOVER_BASE_FLAGS
  fi
}

discover_local() {
  log "info" "<discoverDomain><discover_local><entry> args: $*>"
  file_timestamp=$(date +%Y%m%d%H%M)
  # WDT discover tool
  SCRIPT_PATH="$toolHome/deps/wdt/bin/discoverDomain.sh"
  # Output JSON model
  MODEL_PATH="$toolHome/out/Discovered_${file_timestamp}.json"

  # Ensure java_home came from on-prem.env
  if [ -z "$java_home" ]; then
      log "error" "java_home is not set in on-prem.env"
      exit 2
  fi
  export JAVA_HOME="$java_home"
  log "info" "Using JAVA_HOME = $JAVA_HOME"

  # Execute WDT Discover
  discover "local" "$SCRIPT_PATH" \
           "-domain_home $domain_home" \
           "-java_home $JAVA_HOME" \
           "-model_file $MODEL_PATH" \
           "-skip_archive"
  exit_code=$?
  log "info" "Executed WDT Discover with exit code [$exit_code]"
  if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ]; then
      log "error" "<discoverDomain><discover_local><error> Error executing WDT discover domain"
      exit $exit_code
  fi
  log "info" "<discoverDomain><discover_local><exit> WebLogic Inventory File: $MODEL_PATH"

  # Post-process WDT JSON:
  #   - Insert AdminConsolePort (Admin Server only)
  #   - Insert DomainPath & OraclePath in the topology section
  PYTHON_SCRIPT="$toolHome/lib/python/patch_discover_wls_model.py"
  python3 "$PYTHON_SCRIPT" "$MODEL_PATH" "$ON_PREM_ENV_FILE"
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
      log "error" "<discoverDomain><discover_local><error> JSON post-processing failed with exit code $exit_code"
      exit $exit_code
  fi
  log "info" "Successfully updated WebLogic Inventory File with AdminConsolePort, DomainPath, OraclePath"

  # Update migration metadata
  DISCOVERED_DOMAIN_JSON="$MODEL_PATH"
  update_migration_data_json "wls_json" "$DISCOVERED_DOMAIN_JSON"
}

discover_remote(){
  # http # Future version HTTP Proxy
  # ${x:=default_value}
  #
  log "info" "<discoverDomain><discover_remote><entry> args: $*"
   SCRIPT_PATH="$wdt_home/bin/discoverWLS.sh"
#   SCRIPT_FLAGS="-remote" "-skip_archive" "-ssh_host" "$ssh_admin_server_host" "-ssh_user" "$ssh_user" "-ssh_private_key" "$ssh_private_key_file"
   file_timestamp=`date +%Y%m%d%H%M`
   discover "remote" "$SCRIPT_PATH" "-domain_home" "$domain_home" "-model_file $wdt_home/out/Discovered_$file_timestamp.json" "-skip_archive"
   secure_copy "$wdt_home/out/Discovered_$file_timestamp.json" "$toolHome/out/"
   log "info" "<discoverDomain><discover_remote><exit> success"
}

discover_online(){
  log "info" "<discoverDomain><discover_online><entry> args: $*"
   #WEBLOGIC DOMAIN
    domain_console_url=${domain_console_url:?"domain_console_url property not set. Check onprem.env file. exiting..."} || return $?
    domain_admin_user=${domain_admin_user:?"domain_admin_user property not set. Check onprem.env file. exiting..."} || return $?
    domain_admin_password_file=${domain_admin_password_file:?"domain_admin_password_file property not set. Check onprem.env file. exiting..."} || return $?

   SCRIPT_PATH="discoverWLS.sh"
#   SCRIPT_FLAGS="-remote" "-skip_archive" "-ssh_host" "$ssh_admin_server_host" "-ssh_user" "$ssh_user" "-ssh_private_key" "$ssh_private_key_file"
   discover "$SCRIPT_PATH" "-admin_url" "$domain_console_url" "-admin_user" "$domain_admin_user"
   log "info" "<discoverDomain><discover_online><exit> success"
}

discover_infra_local() {
    log "info" "<discoverDomain><discover_infra_local><entry> args: $*"

    wls_inventory_file="$1"
    file_timestamp=$(date +%Y%m%d%H%M)

    # Validate input file
    if [[ -f "$wls_inventory_file" ]]; then
        input_file="$wls_inventory_file"
    elif [[ -f "$toolHome/out/$wls_inventory_file" ]]; then
        input_file="$toolHome/out/$wls_inventory_file"
    else
        log "error" "<discoverDomain><discover_infra_local><error> model_file $wls_inventory_file not found. exiting."
        exit 2
    fi

    # Output file
    output_file="$toolHome/out/infra_output_${file_timestamp}.json"

    # Python script for patching
    PYTHON_SCRIPT="$toolHome/lib/python/patch_discover_infra_model.py"

    # Call Python script to patch the model file
    log "info" "Executing patch_discover_infra_mode.py on $input_file"
    python3 "$PYTHON_SCRIPT" \
        --input_model "$input_file" \
        --output_model "$output_file" \
        --env_file "$ON_PREM_ENV_FILE"
    exit_code=$?
    log "info" "Executed Python patch script with exit code [$exit_code]"
    if [[ $exit_code -ne 0 ]]; then
        log "error" "<discoverDomain><discover_infra_local><error> Python script failed"
        exit $exit_code
    fi
    log "info" "<discoverDomain><discover_infra_local><exit> infrastructure_file : $output_file"

    # Update migration metadata
    DISCOVERED_INFRA_JSON="$output_file"
    update_migration_data_json "infra_json" "$DISCOVERED_INFRA_JSON"
}

discover_infra_remote(){
   log "info" "<discoverDomain><discover_infra_remote><entry> args: $*"
   wls_inventory_file=$1
   file_timestamp=`date +%Y%m%d%H%M`
   SCRIPT_PATH="$wdt_home/bin/discoverInfra.sh"
   discover "remote" "$SCRIPT_PATH" "-model_file $wdt_home/out/$wls_inventory_file" "-archive_file $wdt_home/out/infra_output_$file_timestamp.json"
   secure_copy "$wdt_home/out/infra_output_$file_timestamp.json" "$toolHome/out/"
   log "info" "<discoverDomain><discover_infra_remote><exit>"
}

process_datasources(){
  # Input file as a parameter to the function
  local wls_inventory_file="$1"

  # Validate input file
  if [[ -f "$wls_inventory_file" ]]; then
      # If the file exists, use it
      input_file="$wls_inventory_file"
  elif [[ -f "$toolHome/out/$wls_inventory_file" ]]; then
      # If not found directly, check in the tool's output directory
      input_file="$toolHome/out/$wls_inventory_file"
  else
      # Log an error if the file is not found
      log "error" "<discoverDomain><process_datasources><error> Model file [$wls_inventory_file] not found in [$toolHome/out]. Exiting."
      exit 2
  fi

  # Path to the Python script for discovering datasources
  PYTHON_SCRIPT="$toolHome/lib/python/discover_ds.py"

  # Log the start of Python script execution
  log "info" "Executing discover_ds.py on [$input_file]"
  python3 "$PYTHON_SCRIPT" \
          --input_model "$input_file" \
          --env_file "$ON_PREM_ENV_FILE"
  exit_code=$?
  log "info" "Executed discover_ds.py with exit code [$exit_code]"
  if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ]; then
      log "error" "<discoverDomain><process_datasources><error> Error executing datasource discovery with exit code [$exit_code]."
      exit $exit_code
  fi
  log "info" "<discoverDomain><process_datasources><exit>"
}

process_archives() {
  local wls_inventory_file="$1"
  local input_file=""

  if [[ -f "$wls_inventory_file" ]]; then
      input_file="$wls_inventory_file"
  elif [[ -f "$toolHome/out/$wls_inventory_file" ]]; then
      input_file="$toolHome/out/$wls_inventory_file"
  else
      log "error" "<discoverDomain><process_archives><error> Model file [$wls_inventory_file] not found in [$toolHome/out]. Exiting."
      exit 2
  fi

  local PYTHON_SCRIPT="$toolHome/lib/python/archive_infra.py"

  log "info" "Executing archive_infra.py on [$input_file]"
  python3 "$PYTHON_SCRIPT" \
      --input-model "$input_file" \
      --tool-home "$toolHome"

  exit_code=$?
  log "info" "Executed archive_infra.py with exit code [$exit_code]"

  if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ]; then
      log "error" "<discoverDomain><process_archives><error> Error executing archive infra with exit code [$exit_code]."
      exit $exit_code
  fi

  if [ $exit_code -eq 1 ]; then
      log "warning" "<discoverDomain><process_archives><warning> Archive executed with warnings"
      exit $exit_code
  fi

  log "info" "<discoverDomain><process_archives><exit>"
}

upload_to_oci(){
  local inventory_file=$1
  local archive_folder_name=$2
  local repository=${3:-$toolHome/out}
  log "info" "<discoverDomain><upload_to_oci><entry> args: $inventory_file $archive_folder_name $repository"
  source $toolHome/bin/uploadArchiveOCI.sh
  upload_to_oss "$inventory_file" "$archive_folder_name" "$repository"
  exit_code=$?
  log "info" "Executed owm.sh lift with exit code [$exit_code]"

  if [ $exit_code -ne 0 ] ; then
    log "error" "<discoverDomain><upload_to_oci><error> Error executing owm.sh lift operation"
    echo "check $LOG_FILE for more details.."
    exit 1
  fi
#  if [[ "$exit_code" == $OP_COMPLETED ]]; then
#     update_oss_auto_tfvars
#  else
#     log "error" "<discoverDomain><upload_to_oci><error> Error uploading archives to oci operation code [$ret_code]"
#     exit 1
#  fi
  log "info" "<discoverDomain><upload_to_oss><exit> "
}

build_orm(){
    local file_timestamp=`date +%Y%m%d%H%M`
    local inventory_file=${1:-none}
    local stack_name=${2:-owm_rm_$file_timestamp}
    log "info" "<owm><build_orm><entry> args: $inventory_file - $stack_name"
    source $toolHome/bin/build_orm.sh -i "$inventory_file" -s "$stack_name"
    ret_code=$?
    echo "Executed build_orm with exit code [$ret_code]"
    #source "${toolHome}/bin/build_orm.sh" -i "$inventory_file" -s "$stack_name" -t
    log "info" "<owm><build_orm><exit> build Oracle Resource Manager completed with return code [$ret_code]"
}

build_orm_test(){
    local file_timestamp=`date +%Y%m%d%H%M`
    local inventory_file=${1:-none}
    local stack_name=${2:-owm_rm_$file_timestamp}
    log "info" "<owm><build_orm><entry> args: $inventory_file - $stack_name"
    source "${toolHome}/bin/build_test.sh" -i "$inventory_file" -s "$stack_name" -t
    log "info" "<owm><build_orm><exit> success"
}


print_help() {
    # Menu Options
    echo "Usage: $0 [option] [env_name]"
    echo "Options:"
    echo "  wls   Discover Weblogic Domain running locally"
#    echo "  remote  Discover Weblogic Domain running on a remote Linux Server"
    echo "  infra   Create an inventory file with Linux Host configured in the Weblogic Domain."
    #echo "  infra-remote   Create an inventory file with Linux Host configured in the Weblogic Domain."
    echo "  archive   Archive Directories -Middleware,JDK, Domains, Custom - and copy it localy"
    echo "  lift   Upload Weblogic Domain archives to OCI Object Storage for a given Inventory file"
    echo "  ds   Process Datasources from WLS Inventory File and configure OCI Resource Manager stack"
    echo "  orm   Build OCI Resource Manager Stack"
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_help
    return 0
fi

case "$1" in
    "wls")
        load_config "$ON_PREM_ENV_FILE"

        # Ensure JAVA_HOME is exported
        if [ -n "$java_home" ]; then
          export JAVA_HOME="$java_home"
        fi
        discover_local
        ;;
    "remote")
        load_config "$ON_PREM_ENV_FILE"
        discover_remote
        ;;
    "infra")
        load_config "$ON_PREM_ENV_FILE"
        discover_infra_local $2
        ;;
    "infra-remote")
        load_config "$ON_PREM_ENV_FILE"
        discover_infra_remote $2
        ;;
    "archive")
       load_config "$ON_PREM_ENV_FILE"
       shift
       process_archives "$1"
       ;;
    "lift")
       load_config "$ON_PREM_ENV_FILE"
       upload_to_oci "$2" "$3"
       ;;
    "ds")
       load_config "$ON_PREM_ENV_FILE"
       process_datasources "$2"
       ;;
    "orm")
       build_orm $2 $3 #Inventory file path and Stack name
       ;;
    "test")
           build_orm_test $2 $3
           ;;
#    "execute")
#          log "info" "Executing the migration process.."
#          ;;
    *)
        echo "Unknown option: $1"
        print_help
        exit 1
        ;;
esac
