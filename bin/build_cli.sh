#!/usr/bin/env bash

# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

############################################################
# Build CLI bundle to run SRG dev tests                                                     #
############################################################

############################################################
# help                                                     #
############################################################
help()
{
  echo
  echo "Arguments: build_cli.sh -t|--scripts_version"
  echo "options:"
  echo "-t, --scripts_version     VM scripts version"
  echo
}

if [ $# -eq 0 ]; then
    help
    exit 1
fi

while [ $# -ne 0 ]
do
    case $1 in
        -h|--help)
            help
            exit 0
            ;;
        -t|--scripts_version)
            SCRIPTS_VERSION="$2"
            shift
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
  if [ -z "${SCRIPTS_VERSION}" ]; then
    echo "vm scripts version is not provided"
    help
    exit 1
  fi
}

#Run validation for the input parameters
validate


cd $(dirname $0)
SCRIPT_DIR=$(pwd)

echo "Cleaning wlsoci folder"
rm -rf ${SCRIPT_DIR}/../oci/generated
echo "Creating wlsoci folder"
TMP_BUILD=${SCRIPT_DIR}/../oci/generated
mkdir -p ${SCRIPT_DIR}/../oci/generated

create_cli_bundle()
{
  cp -Rf ${SCRIPT_DIR}/../oci/iac/modules ${SCRIPT_DIR}/../oci/iac/edition.tf ${SCRIPT_DIR}/../oci/iac/*.tf ${SCRIPT_DIR}/../oci/iac/images ${TMP_BUILD}
  rm ${TMP_BUILD}/modules/validators/stack_validators.tf
  replace_variables
  #  (cd ${TMP_BUILD}; zip -r ${SCRIPT_DIR}/binaries/wlsoci-terraform.zip *; rm -Rf ${TMP_BUILD}/*)
}

#need to change it to false after RM UI fix
replace_variables()
{
   echo "before first sed"
  #  sed -i '/variable "generate_dg_tag" {/!b;n;n;n;cdefault = false' ${TMP_BUILD}/variables.tf
    sed -i .bak -e '/^variable "generate_dg_tag" {/,/}/ s/\(.*default.*\)/default = false/' ${TMP_BUILD}/variables.tf
  #  sed -i -e '/^  #np1 = {/,/}/ s/\(.*ocpus.*\)/#ocpus  = 4,/' $TF_VARS_RUN
    echo "second sed"
  #  sed -i '/variable "use_marketplace_image" {/!b;n;n;n;cdefault = false' ${TMP_BUILD}/mp_variables.tf
    sed -i .bak -e '/^variable "use_marketplace_image" {/,/}/ s/\(.*default.*\)/default = false/' ${TMP_BUILD}/variables.tf
    echo "third sed"
    #sed -i '/variable "tf_script_version" {/!b;n;n;n;cdefault = \"'"$SCRIPTS_VERSION"'\"' ${TMP_BUILD}/variables.tf
    sed -i .bak -e '/^variable "tf_script_version" {/,/}/ s/\(.*default.*\)/default = \"'"$SCRIPTS_VERSION"'\"/' ${TMP_BUILD}/variables.tf

    echo "fourth sed"
#    sed -i '/variable "is_rms_private_endpoint_required" {/!b;n;n;n;cdefault = false' ${TMP_BUILD}/variables.tf
    sed -i .bak -e '/^variable "is_rms_private_endpoint_required" {/,/}/ s/\(.*default.*\)/default = false/' ${TMP_BUILD}/variables.tf

    echo "fith sed"
#    sed -i '/variable "is_bastion_instance_required" {/!b;n;n;n;cdefault = true' ${TMP_BUILD}/bastion_variables.tf
    sed -i .bak  -e '/^variable "is_bastion_instance_required" {/,/}/ s/\(.*default.*\)/default = true/' ${TMP_BUILD}/bastion_variables.tf

    echo "done replacing with sed variables"
}

clean_bak_files()
{
  rm ${TMP_BUILD}/*.bak
}

copy_tfvars_json()
{
  cp ${SCRIPT_DIR}/../oci/stack/terraform.tfvars.json ${TMP_BUILD}
  cp ${SCRIPT_DIR}/../oci/stack/wls.auto.tfvars ${TMP_BUILD}
}

create_cli_bundle
clean_bak_files
copy_tfvars_json
#cleanup
#rm -Rf $TMP_BUILD

exit 0