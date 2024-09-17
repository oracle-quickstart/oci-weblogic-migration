#!/usr/bin/env bash

# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : discoverDomain.sh
# Description          : Discover a Weblogic Domain locally or Remotely.
#############################################################################################################################
scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.." ||exit; pwd)
LOG_FILE_NAME="discoverDomain.log"
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
  #TODO: JOI: Revisit hard coded paths.
  inventory_file=$1
  cd $toolHome/lib/terraform && terraform init && terraform apply --auto-approve -var wls_discovery_filename="$inventory_file" -var inventory_path="$toolHome/out"
  cp $toolHome/out/datasources.auto.tfvars $toolHome/oci/iac2/examples/rms/wls-migrate-inventory/

}


print_help() {
    # Menu Options
    echo "Usage: $0 [option] [env_name]"
    echo "Options:"
    echo "  local   Discover Weblogic Domain running locally"
    echo "  remote  Discover Weblogic Domain running on a remote Linux Server"
    echo "  infra   Create an inventory file with Linux Host configured in the Weblogic Domain."
    echo "  ds   Process Datasources from WLS Inventory File and configure OCI Resource Manager stack"
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_help
    return 0
fi

case "$1" in
    "local")
        load_config "$2"
        discover_local
        ;;
    "remote")
        load_config "$2"
        discover_remote
        ;;
    "infra")
        load_config "$2"
        discover_infra $3
        ;;
    "ds")
       process_datasources $2
       ;;
    *)
        echo "Unknown option: $1"
        print_help
        exit 1
        ;;
esac