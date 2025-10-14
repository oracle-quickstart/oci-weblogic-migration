#!/bin/sh
# *****************************************************************************
# shared.sh
#
# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
#
#     NAME
#       shared.cmd - shared script for use with OCI Migration Tool.
#
#     DESCRIPTION
#       This script contains shared functions for use with OCI Migration Tool scripts.
#
set -o pipefail

scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.."; pwd)
export toolHome

. "$toolHome/deps/wdt/bin/shared.sh"

variableSetup() {

    # set up variables for WLST or Jython execution

    # set the WLSDEPLOY_HOME variable, ignoring any value that was already set

    SCRIPT_DIR="`dirname "$0"`"
    BASEDIR="`cd "${SCRIPT_DIR}" && pwd `"
    WLSDEPLOY_HOME="`cd "${BASEDIR}/../deps/wdt" ; pwd`"
    export WLSDEPLOY_HOME


    # set up logger configuration, see WLSDeployLoggingConfig.java

    LOG_CONFIG_CLASS=oracle.weblogic.deploy.logging.WLSDeployLoggingConfig

    if [ -z "${WLSDEPLOY_LOG_PROPERTIES}" ]; then
        WLSDEPLOY_LOG_PROPERTIES="${WLSDEPLOY_HOME}/etc/logging.properties"; export WLSDEPLOY_LOG_PROPERTIES
    fi

    if [ -z "${WLSDEPLOY_LOG_DIRECTORY}" ]; then
        WLSDEPLOY_LOG_DIRECTORY="${WLSDEPLOY_HOME}/logs"; export WLSDEPLOY_LOG_DIRECTORY
    fi
}

runWlst() {
    # run a WLST script.
    wlstScript=$1
    # save first argument in wlstScript, and discard argument from $@
    shift

    variableSetup

    # set WLST variable to the WLST executable.
    # set CLASSPATH and WLST_CLASSPATH to include the WDT core JAR file.
    # if the WLST_PATH_DIR was set, verify and use that value.

    if [ -n "${WLST_PATH_DIR}" ]; then
        if [ ! -d "${WLST_PATH_DIR}" ]; then
            echo "Specified -wlst_path directory does not exist: ${WLST_PATH_DIR}" >&2
            exit 98
        fi
        WLST="${WLST_PATH_DIR}/common/bin/wlst.sh"
        if [ ! -x "${WLST}" ]; then
            echo "WLST executable ${WLST} not found under -wlst_path directory: ${WLST_PATH_DIR}" >&2
            exit 98
        fi
        CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar: export CLASSPATH
        if [ ! -z "${WLST_EXT_CLASSPATH}" ]; then
          WLST_EXT_CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLST_EXT_CLASSPATH}"; export WLST_EXT_CLASSPATH
        else
          WLST_EXT_CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar: export WLST_EXT_CLASSPATH
        fi
    else
        # if WLST_PATH_DIR was not set, find the WLST executable in one of the known ORACLE_HOME locations.

        WLST=""
        if [ -x "${ORACLE_HOME}/oracle_common/common/bin/wlst.sh" ]; then
            WLST="${ORACLE_HOME}/oracle_common/common/bin/wlst.sh"
            CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar: export CLASSPATH
          if [ ! -z "${WLST_EXT_CLASSPATH}" ]; then
            WLST_EXT_CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLST_EXT_CLASSPATH}"
            export WLST_EXT_CLASSPATH
          else
            WLST_EXT_CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar: export WLST_EXT_CLASSPATH
          fi
        elif [ -x "${ORACLE_HOME}/wlserver_10.3/common/bin/wlst.sh" ]; then
            WLST="${ORACLE_HOME}/wlserver_10.3/common/bin/wlst.sh"
            CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar: export CLASSPATH
        elif [ -x "${ORACLE_HOME}/wlserver_12.1/common/bin/wlst.sh" ]; then
            WLST="${ORACLE_HOME}/wlserver_12.1/common/bin/wlst.sh"
            CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar: export CLASSPATH
        elif [ -x "${ORACLE_HOME}/wlserver/common/bin/wlst.sh" -a -f "${ORACLE_HOME}/wlserver/.product.properties" ]; then
            WLST="${ORACLE_HOME}/wlserver/common/bin/wlst.sh"
            CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar: export CLASSPATH
        fi


        if [ -z "${WLST}" ]; then
            echo "Unable to determine WLS version in ${ORACLE_HOME} to determine WLST shell script to call" >&2
            exit 98
        fi
    fi

    WLST_PROPERTIES=-Dcom.oracle.cie.script.throwException=true
    WLST_PROPERTIES="${WLST_PROPERTIES} -Djava.util.logging.config.class=${LOG_CONFIG_CLASS}"
    WLST_PROPERTIES="${WLST_PROPERTIES} ${WLSDEPLOY_PROPERTIES}"
    export WLST_PROPERTIES

    # print the configuration, and run the script

    #echo "JAVA_HOME = ${JAVA_HOME}"
    echo "WLST_EXT_CLASSPATH = ${WLST_EXT_CLASSPATH}"
    echo "CLASSPATH = ${CLASSPATH}"
    echo "WLST_PROPERTIES = ${WLST_PROPERTIES}"

#    PY_SCRIPTS_PATH="${WLSDEPLOY_HOME}/lib/python"
    PY_SCRIPTS_PATH="${toolHome}/lib/python"

    if [ -z "${OHARG_VALUE}" ] ; then
      echo "${WLST} ${PY_SCRIPTS_PATH}/$wlstScript" "$@"
      "${WLST}" "${PY_SCRIPTS_PATH}/$wlstScript" "$@"
    else
      echo "${WLST} ${PY_SCRIPTS_PATH}/$wlstScript $OHARG ${OHARG_VALUE}" "$@"
      "${WLST}" "${PY_SCRIPTS_PATH}/$wlstScript" $OHARG "${OHARG_VALUE}" "$@"
    fi

    RETURN_CODE=$?
    checkExitCode ${RETURN_CODE}
    exit ${RETURN_CODE}
}

getArg() {
  key="$1"
  shift
  while [ $# -gt 0 ]; do
    if [ "$1" = "$key" ]; then
      echo "$2"
      return 0
    fi
    shift
  done
  return 1
}

#
#readonly OWLSMIG_NAME="OCI Weblogic Migration Tool"
#DEPS_DIR=$toolHome/deps
#readonly DEPS_WDT_HOME=$DEPS_DIR/wdt
#readonly DEPS_JQ_HOME=$DEPS_DIR/jq
#readonly LOG_DIR=$toolHome/logs
#LOG_FILE="$LOG_DIR/$LOG_FILE_NAME"
#readonly WDT_DOWNLOAD_RELEASE_URL="https://github.com/oracle/weblogic-deploy-tooling/releases/download/release-4.2.0/weblogic-deploy.tar.gz"
#readonly JQ_DOWNLOAD_RELEASE_URL="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
#readonly REPO_ARCHIVE_PATH=${3:-$toolHome/out}
#readonly INVENTORY_FILE='wlsdomain.json'
#SSH="ssh"
#
##TODO: Set variable definition.
#PRIV_SSH_KEY_PATH="/home/opc/.ssh/dlp_common"
##"${PRIV_SSH_KEY_PATH:?Variable not set or empty}"
#readonly JUMP_HOST_OPTION="-J opc@t-wlsb"
#
#
#
## shellcheck disable=SC2112
#function start_section() {
#    # printf "    Checking %s requirements... \n" "$1"
#    message="start section $1"
#    log "info" "$message" "<$1>"
#}
#
## shellcheck disable=SC2112
#function end_section() {
#    message="end section $1"
#    log "info" "$message" "<$1>"
#}
#
## shellcheck disable=SC2112
#function log(){
#    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
#    level=$1
#    message=$2
#    section=$3
#    echo "$timestamp" "$section" ["${level^^}"] "$message" | tee -a "$LOG_FILE"
#}
#
#is_empty_dir() {
#    log "info" "is_empty_dir $1"
#    # [[ "*..." = "$(printf %s * .*)" ]];
#    # shellcheck disable=SC2046
#    return $(find $1 -maxdepth 0 -empty)
#}
#
#load_config(){
#  log "info" "loading OnPrem configuration $1"
#  [ ! -f "$1" ] || export $(sed 's/#.*//g' "$1" | xargs)
#  log "info" "Properties loaded $1"
#}
#
#run_ssh_command(){
#     command="$@"
#     # Check required flags are set
#       # Need SSH credentials
#       # Need Admin Console URL with user and password file
#       # ssh_admin_server_host=12.0.0.215           # Weblogic Server Admin IP or hostname.
#         #ssh_user=domain                  # Operating system user with permissions to read
#         #ssh_password_file=                 #/path/to/file_with_ssh_password
#         #ssh_private_key_file=/Users/jortizi/Documents/OPC/OCI/resources/keys/dlp_common              #/path/to/private_key_file
#         #oracle_home=/opt/middleware        #set to ORACLE_HOME in local Linux Server.
#         #jdk_home=                          # set to JDK path in local Linux Server.
#         #node_manager_home=                # set the node_manager_home if Weblogic Deployment Type is Node Manager per Machine.
#         ## [ SSH JumpHost]
#         #ssh_jump_host=129.146.72.166                    # Jumphost IP Address or hostname
#         #ssh_jump_host_user=opc                # username to authenticate on SSH Jumphost
#         #ssh_jump_host_password_file=       #/path/to/ssh_jump_host user password_file
#         #ssh_jump_host_private_key_file=/Users/jortizi/Documents/OPC/OCI/resources/keys/dlp_common    #/path/to/ssh_jump_host user private_key_file
#         ## [ HTTP Proxy]
#         #http_proxy=                         #http proxy server address  i.e http://192.168.0.10:80
#         #https_proxy=                        #https proxy server address  i.e https://192.168.0.10:80
#         #http_proxy_user=                    #http proxy user
#         #http_proxy_password_file=           #/path/to/https proxy_password file
#         ## [ Weblogic Domain]
#         #domain_admin_user=weblogic          # Weblogic Console username
#         #domain_admin_password_file=         #/path/to/file_with_weblogic_console_password
#         #domain_console_url=                 #https://my.host.com:7002/login/console
#
#     #
#     ssh_admin_server_host=${ssh_admin_server_host:?"ssh_admin_server_host property not set. Check onprem.env file. exiting..."} || return $?
#     ssh_user=${ssh_user:?"ssh_user property not set. Check onprem.env file. exiting..."} || return $?
#     ssh_password_file=${ssh_password_file:-none}
#     ssh_private_key_file=${ssh_private_key_file:-none}
#     SSH_HOST_OPTIONS=""
#     SSH_PRE_COMMAND=""
#     SSH_CREDS=""
#     if [[ "$ssh_private_key_file" == "none " && "$ssh_password_file" == "none" ]]; then
#         log "error" "either a file with the user password or ssh private key file must be set. Ref: ssh_password_file and ssh_private_key_file in onprem.env. exiting..."
#         exit 1
#     elif [[ "$ssh_private_key_file" != "none " ]] ;then
#         SSH_HOST_OPTIONS="-i $ssh_private_key_file"
#     elif [[ "$ssh_password_file" != "none" ]] ;then
#         SSH_PRE_COMMAND="sshpass -f $ssh_password_file"
#     fi
#
#    SSH_CREDS="$ssh_user@$ssh_admin_server_host"
#
#     ## [ SSH JumpHost]
#     #ssh_jump_host=129.146.72.166                    # Jumphost IP Address or hostname
#     #ssh_jump_host_user=opc                # username to authenticate on SSH Jumphost
#     SSH_JUMPHOST_COMMAND=""
#     SSH_JUMPHOST_PRE_COMMAND=""
#     SSH_JUMPHOST_OPTIONS=""
#     SSH_JUMPHOST_CREDS=""
#     #ssh_jump_host_password_file=       #/path/to/ssh_jump_host user password_file
#     #ssh_jump_host_private_key_file=/path/to/private.key    #/path/to/ssh_jump_host user private_key_file
#     ssh_jump_host_password_file=${ssh_jump_host_password_file:-none}
#     ssh_jump_host_private_key_file=${ssh_jump_host_private_key_file:-none}
#     if [[ "$ssh_jump_host_private_key_file" != "none" ]]; then
#         SSH_JUMPHOST_OPTIONS="-i $ssh_jump_host_private_key_file"
#     elif [[ "$ssh_jump_host_password_file" != "none" ]]; then
#         SSH_JUMPHOST_PRE_COMMAND="sshpass -f $ssh_jump_host_password_file"
#     fi
#     if [[ "$ssh_jump_host_user@$ssh_jump_host" != "@" ]]; then
#           log "info" "jump host set.  $ssh_jump_host"
#           SSH_JUMPHOST_CREDS="$ssh_jump_host@$ssh_jump_host_user"
#           SSH_JUMPHOST_COMMAND="-o ProxyCommand=\"$SSH_JUMPHOST_PRE_COMMAND $SSH_JUMPHOST_CREDS $SSH_JUMPHOST_OPTIONS\""
#     fi
#
#     SSH_COMMAND="$SSH_PRE_COMMAND $SSH $SSH_JUMPHOST_COMMAND $SSH_HOST_OPTIONS $SSH_CREDS"
#     log "info" "Running Remote command: $command"
#     echo "$SSH_COMMAND"
#     if $($SSH_COMMAND "$command") >> "$LOG_FILE" 2>&1; then
#         log "error" "Failed to run command remotely. Check logs.  exiting..."
#         exit 1
#     fi
#
#}
#
#export user_functions_loaded=0