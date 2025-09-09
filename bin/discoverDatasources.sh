#!/bin/sh
# *****************************************************************************
# discoverDatasources.sh
#
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#     NAME
#       discoverDatasources.sh - Tool to discover datasources in a Weblogic Domain Model file and update a Resource Manager Stack Terraform variable file
#
#     DESCRIPTION
#       This script attempts to discover jdbc strings in a Model json file.
#       Sorts, classifies jdbc strings and generate a Terraform Varaible datasource.auto.tfvars file
#       to be included in the Resources Manager Migration Stack.
#
# This script uses the following variables:
#
# JAVA_HOME             - The path to the Java Home directory used by the ORACLE HOME.
#                         This overrides the JAVA_HOME value when locating attributes
#                         which will be replaced with the java home global token in the model
#
# WLSDEPLOY_PROPERTIES  - Extra system properties to pass to WLST.  The caller
#                         can use this environment variable to add additional
#                         system properties to the WLST environment.
#

usage() {
  echo ""
  echo "Usage: $1 [-help]"
  echo "          [-oracle_home <oracle_home>]"
  echo "          [-model_file model_file]"
  echo "          [-variable_file out/datasource.auto.tfvars]"
  echo "          [-remote_test_file <remote_test_file> -local_output_dir <local_output_dir>]"
  echo "          [-local_test_file <local_test_file> -remote_output_dir <remote_output_dir>]"
  echo "          [-wlst_path <wlst_path>]"
  echo ""
  echo "    where:"
  echo "        oracle_home     - the existing Oracle Home directory for the domain."
  echo "                          This argument is required unless the ORACLE_HOME"
  echo "                          environment variable is set."
  echo ""
  echo "        model_file       - The Discovered Domain Model file."
  echo "                          This argument is required and should include the path to the model file."
  echo ""
  echo "        variable_file     - Overwrite default Terraform Variable filename (toolHome)/datasource.auto.tfvars"
  echo "                          This argument is optional and should include the path to the model file."
  echo ""
  echo "        wlst_path       - the Oracle Home subdirectory of the wlst.sh"
  echo "                          script to use (e.g., <ORACLE_HOME>/soa)."
  echo ""
}

WLSDEPLOY_PROGRAM_NAME="discover"; export WLSDEPLOY_PROGRAM_NAME

scriptName=$(basename "$0")
scriptPath=$(dirname "$0")

. "$scriptPath/common.sh"

WLSDEPLOY_LOG_DIRECTORY="$toolHome/logs"; export  WLSDEPLOY_LOG_DIRECTORY

umask 27

checkArgs "$@"

minJdkVersion=7
if [ "$USE_ENCRYPTION" == "true" ]; then
  minJdkVersion=8
fi

# required Java version is dependent on use of encryption
javaSetup $minJdkVersion
export PYTHONPATH=$PWD/lib
runWlst datasource_discovery.py "$@"
