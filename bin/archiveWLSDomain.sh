#!/bin/sh
# *****************************************************************************
# archiveWLSDomain.sh
#
# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
#
#     NAME
#       archiveWLSDomain.sh - Tool to package local or remote java_home, WLS_HOME, DOMAIN_HOME and custom directories
#
#     DESCRIPTION
#       This script attempts to establish an SSH connection to every machine found in a Weblogic discovered Domain
#       with the provided configuration.
#
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
  echo "          -ssh_host <ssh_host> [-ssh_port <ssh_port>]"
  echo "          [-ssh_user <ssh_user>]"
  echo "          ["
  echo "           -ssh_pass_env <ssh_pass_env> |"
  echo "           -ssh_pass_file <ssh_pass_file> |"
  echo "           -ssh_pass_prompt"
  echo "          ]"
  echo "          [-ssh_private_key <ssh_private_key>]"
  echo "          ["
  echo "           -ssh_private_key_pass_env <ssh_private_key_pass_env> |"
  echo "           -ssh_private_key_pass_file <ssh_private_key_pass_file> |"
  echo "           -ssh_private_key_pass_prompt"
  echo "          ]"
  echo "          ["
  echo "            -local_output_dir <local_output_dir> |"
  echo "            -remote_output_dir <remote_output_dir> |"
  echo "            -skip_archive"
  echo "          ]"
  echo "    where:"
  echo "        oracle_home     - the existing Oracle Home directory for the domain."
  echo "                          This argument is required unless the ORACLE_HOME"
  echo "                          environment variable is set."
  echo "        local_output_dir   - Local Path to store archives"
  echo "        remote_output_dir  - Path on Remote Host to store archives"
  echo "        skip_archive       - Skip archive compression and show commands to run on each remote host"
  echo "        ssh_host        - the hostname or IP address of the remote machine.  This"
  echo "                          argument is required."
  echo ""
  echo "        ssh_port        - the port number to use to connect to the remote machine."
  echo "                          This argument is optional and defaults to 22, if not"
  echo "                          specified."
  echo ""
  echo "        ssh_user        - the SSH user name on the remote machine.  This argument"
  echo "                          is optional and defaults to the current user on the"
  echo "                          local machine, as determined by the user.name Java"
  echo "                          system property."
  echo ""
  echo "        ssh_pass_env    - An alternative to entering the SSH user's password"
  echo "                          at a prompt. The value is an ENVIRONMENT VARIABLE"
  echo "                          name that WDT will use to retrieve the password."
  echo "                          This argument should only be used when using"
  echo "                          username/password-based authentication."
  echo ""
  echo "        ssh_pass_file   - An alternative to entering SSH user's password"
  echo "                          at a prompt. The value is the name of a file with a"
  echo "                          string value which WDT will read to retrieve the"
  echo "                          password.  This argument should only be used"
  echo "                          when using username/password-based authentication."
  echo ""
  echo "        ssh_private_key - the path to the private key to use for SSH"
  echo "                          authentication.  This argument is optional and defaults"
  echo "                          to the normal default SSH key (e.g., ~/.ssh/id_rsa)."
  echo "                          This argument should only be used when using"
  echo "                          public key-based authentication."
  echo ""
  echo "        ssh_private_key_pass_env - An alternative to entering the private key"
  echo "                          passphrase at a prompt. The value is an ENVIRONMENT"
  echo "                          VARIABLE name that WDT will use to retrieve the"
  echo "                          password.  This argument should only be used when"
  echo "                          using public key-based authentication and the"
  echo "                          private key is encrypted with a passphrase."
  echo ""
  echo "        ssh_private_key_pass_file - An alternative to entering SSH private key"
  echo "                          passphrase at a prompt. The value is the name of a"
  echo "                          file with a string value which WDT will read to"
  echo "                          retrieve the password.  This argument should only be"
  echo "                          used when using username/password-based"
  echo "                          authentication and the private key is encrypted with"
  echo "                          a passphrase."
  echo "    The -ssh_pass_prompt argument tells WDT to prompt for the SSH user's"
  echo "    password and read it from standard input.  This is also useful for"
  echo "    scripts that want to pipe the value into the tool's standard input."
  echo ""
  echo "    The -ssh_private_key_pass_prompt argument tells WDT to prompt for the"
  echo "    private key passphrase and read it from standard input. This is also"
  echo "    useful for scripts that want to pipe the value into the tool's"
  echo "    standard input."
  echo ""
}

WLSDEPLOY_PROGRAM_NAME="archiveHelper"; export WLSDEPLOY_PROGRAM_NAME

scriptName=$(basename "$0")
scriptPath=$(dirname "$0")

. "$scriptPath/common.sh"

WLSDEPLOY_LOG_DIRECTORY="$toolHome/logs"; export  WLSDEPLOY_LOG_DIRECTORY

umask 27

checkArgs "$@"

export PYTHONPATH=$PWD/lib
runWlst archive_infra.py "$@"
