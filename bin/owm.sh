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
ON_PREM_ENV_FILE="$toolHome/config"

[ "$user_functions_loaded" ] || source ./shared.sh

discover(){
  EXEC_TYPE=$1
  SCRIPT_PATH=$2
  shift; shift
  DISCOVER_BASE_FLAGS="-oracle_home $oracle_home  $@"
  if [[ "$EXEC_TYPE" == "remote" ]]; then
      run_ssh_command "$SCRIPT_PATH" "$DISCOVER_BASE_FLAGS"
  else
     bash "$SCRIPT_PATH" "$DISCOVER_BASE_FLAGS"
  fi
}

discover_local(){
  SCRIPT_PATH="discoverWLS.sh" "-domain_home" "$domain_home" "-skip_archive" "-model_file $toolHome/out/Discovered_`date +%Y%m%d%H%M`.json"
  discover "local" "$SCRIPT_PATH"
}


discover_remote(){
  # http # Future version HTTP Proxy
  # ${x:=default_value}
  #
   SCRIPT_PATH="$wdt_home/bin/discoverWLS.sh"
#   SCRIPT_FLAGS="-remote" "-skip_archive" "-ssh_host" "$ssh_admin_server_host" "-ssh_user" "$ssh_user" "-ssh_private_key" "$ssh_private_key_file"
   file_timestamp=`date +%Y%m%d%H%M`
   discover "remote" "$SCRIPT_PATH" "-domain_home" "$domain_home" "-model_file $wdt_home/out/Discovered_$file_timestamp.json" "-skip_archive"
   secure_copy "$wdt_home/out/Discovered_$file_timestamp.json" "$toolHome/out/"
}

discover_online(){
   #WEBLOGIC DOMAIN
    domain_console_url=${domain_console_url:?"domain_console_url property not set. Check onprem.env file. exiting..."} || return $?
    domain_admin_user=${domain_admin_user:?"domain_admin_user property not set. Check onprem.env file. exiting..."} || return $?
    domain_admin_password_file=${domain_admin_password_file:?"domain_admin_password_file property not set. Check onprem.env file. exiting..."} || return $?

   SCRIPT_PATH="discoverWLS.sh"
#   SCRIPT_FLAGS="-remote" "-skip_archive" "-ssh_host" "$ssh_admin_server_host" "-ssh_user" "$ssh_user" "-ssh_private_key" "$ssh_private_key_file"
   discover "$SCRIPT_PATH" "-admin_url" "$domain_console_url" "-admin_user" "$domain_admin_user"
}

discover_infra(){
#  alias dinf="`pwd`/discoverInfra.sh -oracle_home /opt/middleware -model_file Discovered_`date +%F`.json -archive_file infra_output__`date +%F`.json"
   wls_inventory_file=$1
   file_timestamp=`date +%Y%m%d%H%M`
   SCRIPT_PATH="$wdt_home/bin/discoverInfra.sh"
   discover "remote" "$SCRIPT_PATH" "-model_file $wdt_home/out/$wls_inventory_file" "-archive_file $wdt_home/out/infra_output_$file_timestamp.json"
   secure_copy "$wdt_home/out/infra_output_$file_timestamp.json" "$toolHome/out/"
}

process_datasources(){
  wls_inventory_file=$1
  SCRIPT_PATH="$wdt_home/bin/discoverDatasources.sh"
#  ./discoverDatasources.sh -oracle_home /home/opc/mw/ -model_file Discovered_RAC.json
#  discover "remote" "$SCRIPT_PATH" "-model_file $wdt_home/out/$wls_inventory_file" "-archive_file $wdt_home/out/infra_output_$file_timestamp.json"
  discover "remote" "$SCRIPT_PATH" "-model_file $wdt_home/out/$wls_inventory_file"
  secure_copy "$wdt_home/oci/generated/schema.yaml" "$toolHome/oci/generated/"
  secure_copy "$wdt_home/oci/generated/db-connection-string.auto.tfvars" "$toolHome/oci/generated/"
  secure_copy "$wdt_home/oci/generated/locals-db-connection-string.tf" "$toolHome/oci/generated/"
  secure_copy "$wdt_home/oci/generated/data-oci-db-resources.tf" "$toolHome/oci/generated/"
  secure_copy "$wdt_home/oci/generated/variables-db-connection-string.tf" "$toolHome/oci/generated/"
}

process_archives(){
#  local inventory_file=$1
#  local archive_folder_name=$2
#  local dry_run=$3
  log "info" "<discoverDomain><process_archives><entry> args: $*"
#  source $toolHome/bin/archiveWLSDomain.sh
#  archive_repository_path=$3
#  $toolHome/bin/archiveWLSDomain.sh $inventory_file $archive_folder_name  $archive_repository_path
   #archiveWLSDomain "$inventory_file" "$archive_folder_name" "$repository"
   source "${toolHome}/bin/archiveWLSDomain.sh" "$@"
   log "info" "<discoverDomain><process_archives><exit> success"
}

upload_to_oci(){
  local inventory_file=$1
  local archive_folder_name=$2
  local repository=${3:-$toolHome/out}
  log "info" "<discoverDomain><upload_to_oss><entry> args: $inventory_file $archive_folder_name $repository"
  source $toolHome/bin/uploadArchiveOCI.sh
  ret_code=$(upload_to_oss "$inventory_file" "$archive_folder_name" "$repository")
  if [[ "$ret_code" == OP_COMPLETED ]]; then
     update_oss_auto_tfvars
  fi
#  upload_to_oss "$inventory_file" "$archive_folder_name" "$repository"
  log "info" "<discoverDomain><upload_to_oss><exit> success"
}

build_orm(){
    local file_timestamp=`date +%Y%m%d%H%M`
    local inventory_file=${1:-none}
    local stack_name=${2:-owm_rm_$file_timestamp}
    log "info" "<owm><build_orm><entry> args: $inventory_file - $stack_name"
#    ret_code=$(source $toolHome/bin/build_orm.sh -i "$inventory_file" -s "$stack_name" )
    source "${toolHome}/bin/build_orm.sh" -i "$inventory_file" -s "$stack_name" -t
    log "info" "<owm><build_orm><exit> success"
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
    echo "  discover   Discover Weblogic Domain running locally"
#    echo "  remote  Discover Weblogic Domain running on a remote Linux Server"
    echo "  infra   Create an inventory file with Linux Host configured in the Weblogic Domain."
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
    "discover")
        load_config "$2"
        discover_local
        ;;
    "wls")
        load_config "$2"
        discover_remote
        ;;
    "infra")
        load_config "$2"
        discover_infra $3
        ;;
    "archive")
       load_config "$2"
       shift; shift
       #process_archives "$3" "$4" "$5"
       process_archives $@

       ;;
    "lift")
       load_config "$2"
       upload_to_oci "$3" "$4"
       ;;
    "ds")
       load_config "$2"
       process_datasources $3
       ;;
    "orm")
       build_orm $2 $3
       ;;
    "test")
           build_orm_test $2 $3
           ;;
    *)
        echo "Unknown option: $1"
        print_help
        exit 1
        ;;
esac