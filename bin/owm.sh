#!/usr/bin/env bash

# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : owm.sh
# Description          : Discovers a Weblogic Domain Environment and move it to Oracle Cloud.
#############################################################################################################################
scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.." ||exit; pwd)
LOG_FILE_NAME="owm.log"
# echo $scriptPath
# echo $toolHome
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

discover_local(){
  log "info" "<discoverDomain><discover_local><entry> args: $*"
  file_timestamp=`date +%Y%m%d%H%M`
  SCRIPT_PATH="$toolHome/bin/discoverWLS.sh"
  discover "local" "$SCRIPT_PATH" "-domain_home $domain_home" "-model_file $toolHome/out/Discovered_$file_timestamp.json" "-skip_archive"
  exit_code=$?
  log "info" "Executed discover WebLogic with exit code [$exit_code]"
  if [ $exit_code -ne 0 ]; then
     log "error" "<discoverDomain><discover_local><error> Error executing discover infra"
     exit 1
  fi
  log "info" "<discoverDomain><discover_infra_local><exit> WebLogic Inventory File : $toolHome/out/Discovered_$file_timestamp.json"
  DISCOVERED_DOMAIN_JSON="$toolHome/out/Discovered_$file_timestamp.json"
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

discover_infra_local(){
   log "info" "<discoverDomain><discover_infra_local><entry> args: $*"
   wls_inventory_file=$1
   local file_timestamp=`date +%Y%m%d%H%M`
   local SCRIPT_PATH="$toolHome/bin/discoverInfra.sh"
   local model_file_arg=""
   if [[ -f $wls_inventory_file ]]; then
      model_file_arg="-model_file $wls_inventory_file"
   elif [[ -f "$toolHome/out/$wls_inventory_file" ]]; then
      model_file_arg="-model_file $toolHome/out/$wls_inventory_file"
   else
       log "error" "<discoverDomain><discover_infra_local><error> model_file $wls_inventory_file not found. exiting."
       exit 1
   fi
   discover "local" "$SCRIPT_PATH" "$model_file_arg" "-archive_file $toolHome/out/infra_output_$file_timestamp.json"
   exit_code=$?
   log "info" "Executed discover infra with exit code [$exit_code]"
   if [ $exit_code -ne 0 ]; then
       log "error" "<discoverDomain><discover_infra_local><error> Error executing discover infra"
       exit 1
   fi
   log "info" "<discoverDomain><discover_infra_local><exit> infrastructure_file : $toolHome/out/infra_output_$file_timestamp.json"
   DISCOVERED_INFRA_JSON="$toolHome/out/infra_output_$file_timestamp.json"
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
  local wls_inventory_file=$1
  SCRIPT_PATH="$toolHome/bin/discoverDatasources.sh"
#  ./discoverDatasources.sh -oracle_home /home/opc/mw/ -model_file Discovered_RAC.json
#  discover "remote" "$SCRIPT_PATH" "-model_file $wdt_home/out/$wls_inventory_file" "-archive_file $wdt_home/out/infra_output_$file_timestamp.json"
#  discover "local" "$SCRIPT_PATH" "-model_file $toolHome/out/$wls_inventory_file"
  discover "local" "$SCRIPT_PATH" "-model_file $wls_inventory_file"
#  cp "$toolHome/oci/generated/schema.yaml" "$toolHome/oci/generated/"
#  cp "$toolHome/oci/generated/db-connection-string.auto.tfvars" "$toolHome/oci/generated/"
#  cp "$toolHome/oci/generated/locals-db-connection-string.tf" "$toolHome/oci/generated/"
#  cp "$toolHome/oci/generated/data-oci-db-resources.tf" "$toolHome/oci/generated/"
#  cp "$toolHome/oci/generated/variables-db-connection-string.tf" "$toolHome/oci/generated/"
  log "info" "<discoverDomain><process_datasources><exit>"
}

function process_archives() {
  log "info" "<discoverDomain><process_archives><entry> args: $*"
  wls_inventory_file=$1
  shift
  SCRIPT_PATH="$toolHome/bin/archiveWLSDomain.sh"
  local model_file_arg=""
     if [[ -f $wls_inventory_file ]]; then
        model_file_arg="-model_file $wls_inventory_file"
     elif [[ -f "$toolHome/out/$wls_inventory_file" ]]; then
        model_file_arg="-model_file $toolHome/out/$wls_inventory_file"
     else
         log "error" "<discoverDomain><process_archives><error> model_file $wls_inventory_file not found. exiting."
         exit 1
     fi
      discover "local" "$SCRIPT_PATH" "$model_file_arg" "-remote_output_dir /tmp" "-local_output_dir $toolHome/out" "$@"
     exit_code=$?
     log "info" "Executed discover infra with exit code [$exit_code]"
     if [ $exit_code -ne 0 ]; then
         log "error" "<discoverDomain><process_archives><error> Error executing discover infra"
         exit 1
     fi
     log "info" "<discoverDomain><process_archives><exit> infrastructure_file : $toolHome/out/infra_output_$file_timestamp.json"

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
       process_archives "$2"
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
