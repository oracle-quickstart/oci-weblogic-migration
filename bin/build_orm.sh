#!/usr/bin/env bash

# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#######################################################################################################
# Build the Oracle Resource Manager (ORM) Stack bundles.  #
# example ./build_orm.sh -i ../out/Discovered_multi_connection_string.json -s owm_rm_`date +%Y%m%d%H%M`
#######################################################################################################
scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.." ||exit; pwd)
LOG_FILE_NAME="build_rm_stack.log"
ON_PREM_ENV_FILE="$toolHome/config"

[ "$user_functions_loaded" ] || source ./shared.sh
log "info" "<build_orm><init> shared functions loaded"
############################################################
#
#
############################################################
set -e
# Trap the EXIT signal to ensure cleanup
#trap cleanup EXIT
trap 'cleanup $? $LINENO' EXIT

# Create a temporary directory and files
TMP_BUILD=$(mktemp -d)
log "info" "<build_orm><init> temporary directory created $TMP_BUILD"
# Function to clean up temporary files
cleanup() {
  rm -rf "$TMP_BUILD"
  if [ "$1" != "0" ]; then
    log "error" "Script exit with error code: $1"
  fi

}



############################################################
# help                                                     #
############################################################
help()
{
  echo "Build the Oracle Resource Manager (ORM) bundles for developers to deploy in Marketplace"
  echo
  echo "Arguments: build_orm.sh -s|--stack <stack_name> -i|--inventory <path_to_file>"
  echo "options:"
  echo "-s, --stack         Stack Name"
  echo "-i, --inventory     Inventory File (JSON Format)"
  echo
}

if [ $# -eq 0 ]; then
    help
    exit 1
fi

log "info" "<build_orm><init> parsing flags"
while [ $# -ne 0 ]
do
    case $1 in
        -h|--help)
            help
            exit 1
            ;;
        -s|--stack)
            STACK_NAME="$2"
	          shift
            ;;
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift
            ;;
        -t|--test)
            BUILD_TEST="debug"
            ;;
        *)
            help
            exit 1
            ;;
    esac
    shift
done

# validate the input parameters
validate()
{
  log "info" "<build_orm><validate><entry>"
  if [ -z "${STACK_NAME}" ]; then
    echo "Stack name argument missing. exiting.."
    help
    exit 1
  elif [ "z${STACK_NAME}" == "z-s" ] || [ "z${STACK_NAME}" == "z--stack" ]; then
     echo "Stack name argument missing. exiting.."
     help
     exit 1
  fi

  if [ -z "${INVENTORY_FILE}" ]; then
     echo "Inventory file missing. exiting.."
     help
     exit 1
  elif [ "z${INVENTORY_FILE}" == "z-i" ] || [ "z${INVENTORY_FILE}" == "z--inventory" ] || [ "z${INVENTORY_FILE}" == "znone" ]; then
       echo "Inventory file missing. exiting.."
       help
       exit 1
  fi
#  echo "$STACK_NAME"
#  echo "$INVENTORY_FILE"
  log "info" "<build_orm><validate><exit> $STACK_NAME $INVENTORY_FILE"
}

#Run validation for the input parameters
validate

# creates a Resource Manager zip file
# Args:
#   toolHome  :   Weblogic Migration tool home.
#   TMP_BUILD :   Temparary directory to store terraform files
#   STACK_NAME :  Zip file name .  Name Pattern:  owm_rm_202410302018.zip
#   INVENTORY_FILE : JSON formated file with Weblogic Domain inventory.
create_bundle(){
#  TMP_BUILD/ -> path for Resource Manager Stack Front
#  TMP_BUILD/inventory  -> path to store Weblogic Domain Discovery Output. JSON Formatted.
#  TMP_BUILD/iac  ->  Resource Manager root Module  - Base Module with Stack logic
#
  log "info" "<build_orm><create_bundle><entry>"
  cp -Rf ${toolHome}/oci/rm/*.tf ${toolHome}/oci/rm/*.tfvars ${TMP_BUILD}/
  cp -Rf ${toolHome}/oci/rm/iac  ${TMP_BUILD}/
  #  Copy generated schema to wls-inventory folder
  cp -Rf ${toolHome}/oci/generated/schema.yaml ${TMP_BUILD}/
  # Copy datasource inventory generated files
  cp -Rf ${toolHome}/oci/generated/*.tf ${TMP_BUILD}/
  cp -Rf ${toolHome}/oci/generated/*.tfvars ${TMP_BUILD}/
  log "info" "<build_orm><create_bundle> terraform files copied to temporay stack $TMP_BUILD"
  #TODO does the provider file need to be included?
#  cp -f ${toolHome}/oci/iac2/orm/orm_provider.tf ${TMP_BUILD}/provider.tf
  #TODO module path should not change. Update logic to pull from repo
#  replace_module_source
  mkdir -p ${TMP_BUILD}/inventory/
  cp -f $INVENTORY_FILE ${TMP_BUILD}/inventory/wlsdomain.json
  if [ "${BUILD_TEST}" == "debug" ]; then
       log "info" "<build_orm><create_bundle><debug> enabled"
       cp ${toolHome}/oci/test/auto/storage.auto.env ${TMP_BUILD}/storage.auto.tfvars
       cp ${toolHome}/oci/test/auto/sec.auto.env ${TMP_BUILD}/sec.auto.tfvars
#       cp ${toolHome}/oci/test/auto/network.auto.env ${TMP_BUILD}/network.auto.tfvars
       generate_random_network_details
       cp ${toolHome}/oci/test/auto/bastion.auto.env ${TMP_BUILD}/bastion.auto.tfvars
       cp ${toolHome}/oci/test/auto/wlsservers.auto.env ${TMP_BUILD}/wlsservers.auto.tfvars
       cp ${toolHome}/oci/test/auto/stack.auto.env ${TMP_BUILD}/stack.auto.tfvars
       log "info" "<build_orm><create_bundle><debug> ORM Stack built for development"
  fi
  (cd ${TMP_BUILD}; zip -r ${toolHome}/oci/stack/$STACK_NAME.zip *;)
  if [[ -f "${toolHome}/oci/stack/$STACK_NAME.zip" ]]; then
      update_migration_data_json "stack_file" "${toolHome}/oci/stack/$STACK_NAME.zip"
      log "info" "<build_orm><create_bundle> Stack file created ${toolHome}/oci/stack/$STACK_NAME.zip"
  else
     log "error" "<build_orm><create_bundle> <error> Resource Mananger Stack file not created "
  fi
  log "info" "<build_orm><create_bundle><exit>"
}

generate_random_network_details()
{
  echo "vcn_name=\"joicito`uuidgen | cut -c 1-4`\"" > ${TMP_BUILD}/network.auto.tfvars
  echo "vcn_dns_label=\"joilabel`uuidgen | cut -c 1-4`\"" >> ${TMP_BUILD}/network.auto.tfvars
}

replace_module_source(){
  log "info" "replacing module source."
  sed -i -e 's|\(.*source=.*\)|source="../"|' ${TMP_BUILD}/main.tf
  log "info" "replacing module source . Done"
}

#need to change it to false after RM UI fix
replace_variables()
{
  log "info" "before first sed"
#  sed -i '/variable "generate_dg_tag" {/!b;n;n;n;cdefault = false' ${TMP_BUILD}/variables.tf
  sed -i'' -e '/^variable "generate_dg_tag" {/,/}/ s/\(.*default.*\)/default = false/' ${TMP_BUILD}/variables.tf
#  sed -i -e '/^  #np1 = {/,/}/ s/\(.*ocpus.*\)/#ocpus  = 4,/' $TF_VARS_RUN
  log "info" "second sed"
#  sed -i '/variable "use_marketplace_image" {/!b;n;n;n;cdefault = false' ${TMP_BUILD}/mp_variables.tf
  sed -i'' -e '/^variable "use_marketplace_image" {/,/}/ s/\(.*default.*\)/default = false/' ${TMP_BUILD}/variables.tf
  log "info" "third sed"
  #sed -i '/variable "tf_script_version" {/!b;n;n;n;cdefault = \"'"$SCRIPTS_VERSION"'\"' ${TMP_BUILD}/variables.tf
  sed -i'' -e '/^variable "tf_script_version" {/,/}/ s/\(.*default.*\)/default = \"'"$SCRIPTS_VERSION"'\"/' ${TMP_BUILD}/variables.tf
  log "info" "done replacing with sed variables 12214"
}

deploy_to_orm(){
  log "info" "<build_orm><deploy_to_orm><entry>"
  oci resource-manager stack create --compartment-id ${OCI_COMPARTMENT_ID} --config-source ${toolHome}/oci/stack/$STACK_NAME.zip >> "$LOG_FILE" || (log "error" "failed to deploy Stack to OCI ... exiting" ; exit 1)
  log "info" "<build_orm><deploy_to_orm><exit>"
}

create_bundle
#deploy_to_orm
