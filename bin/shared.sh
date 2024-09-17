#!/bin/bash
# *****************************************************************************
# shared.sh
#
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#     NAME
#       shared.sh - shared script for use with OCI Migration Tool.
#
#     DESCRIPTION
#       This script contains shared functions for use with OCI Migration Tool scripts.
#
set -o pipefail
#set -x

scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.."; pwd)
#echo $toolHome

readonly OWLSMIG_NAME="OCI Weblogic Migration Tool"
DEPS_DIR=$toolHome/deps
readonly DEPS_WDT_HOME=$DEPS_DIR/wdt
readonly DEPS_JQ_HOME=$DEPS_DIR/jq
readonly LOG_DIR=$toolHome/logs
LOG_FILE="$LOG_DIR/$LOG_FILE_NAME"
readonly WDT_DOWNLOAD_RELEASE_URL="https://github.com/oracle/weblogic-deploy-tooling/releases/download/release-4.2.0/weblogic-deploy.tar.gz"
readonly JQ_DOWNLOAD_RELEASE_URL="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
readonly REPO_ARCHIVE_PATH=${3:-$toolHome/out}
readonly INVENTORY_FILE='wlsdomain.json'
readonly SSH=/usr/bin/ssh
readonly SECURE_COPY_TOOL=/usr/bin/scp
#TODO: Set variable definition.
#PRIV_SSH_KEY_PATH="/home/opc/.ssh/dlp_common"
#"${PRIV_SSH_KEY_PATH:?Variable not set or empty}"




# shellcheck disable=SC2112
function start_section() {
    # printf "    Checking %s requirements... \n" "$1"
    message="start section $1"
    log "info" "$message" "<$1>"
}

# shellcheck disable=SC2112
function end_section() {
    message="end section $1"
    log "info" "$message" "<$1>"
}

# shellcheck disable=SC2112
function log(){
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    level=$1
    message=$2
    section=$3
    echo "$timestamp" "$section" "${level}" "$message" | tee -a "$LOG_FILE"
    #echo "$timestamp" "$section" ["${level^^}"] "$message"  | tee /dev/fd/3
    #exec 3>&1 1>"$LOG_FILE" 2>&1
}

is_empty_dir() {
    log "info" "is_empty_dir $1"
    # [[ "*..." = "$(printf %s * .*)" ]];
    # shellcheck disable=SC2046
    return $(find $1 -maxdepth 0 -empty)
}

load_config(){
  log "info" "loading OnPrem configuration $1"
  [ ! -f "$1" ] || export $(sed 's/#.*//g' "$1" | xargs)
  log "info" "Properties loaded $1"
}

run_ssh_command(){
     command="$@"
     log "info" "Running Remote command: $command"
     # Check required flags are set
       # Need SSH credentials
       # Need Admin Console URL with user and password file
       # ssh_admin_server_host=12.0.0.215           # Weblogic Server Admin IP or hostname.
         #ssh_user=domain                  # Operating system user with permissions to read
         #ssh_password_file=                 #/path/to/file_with_ssh_password
         #ssh_private_key_file=/Users/jortizi/Documents/OPC/OCI/resources/keys/dlp_common              #/path/to/private_key_file
         #oracle_home=/opt/middleware        #set to ORACLE_HOME in local Linux Server.
         #jdk_home=                          # set to JDK path in local Linux Server.
         #node_manager_home=                # set the node_manager_home if Weblogic Deployment Type is Node Manager per Machine.
         ## [ SSH JumpHost]
         #ssh_jump_host=129.146.72.166                    # Jumphost IP Address or hostname
         #ssh_jump_host_user=opc                # username to authenticate on SSH Jumphost
         #ssh_jump_host_password_file=       #/path/to/ssh_jump_host user password_file
         #ssh_jump_host_private_key_file=/Users/jortizi/Documents/OPC/OCI/resources/keys/dlp_common    #/path/to/ssh_jump_host user private_key_file
         ## [ HTTP Proxy]
         #http_proxy=                         #http proxy server address  i.e http://192.168.0.10:80
         #https_proxy=                        #https proxy server address  i.e https://192.168.0.10:80
         #http_proxy_user=                    #http proxy user
         #http_proxy_password_file=           #/path/to/https proxy_password file
         ## [ Weblogic Domain]
         #domain_admin_user=weblogic          # Weblogic Console username
         #domain_admin_password_file=         #/path/to/file_with_weblogic_console_password
         #domain_console_url=                 #https://my.host.com:7002/login/console

     #
     ssh_admin_server_host=${ssh_admin_server_host:?"ssh_admin_server_host property not set. Check onprem.env file. exiting..."} || return $?
     ssh_user=${ssh_user:?"ssh_user property not set. Check onprem.env file. exiting..."} || return $?
     ssh_password_file=${ssh_password_file:-none}
     ssh_private_key_file=${ssh_private_key_file:-none}
     SSH_COMMAND=()
#     SSH_COMMAND=""
     SSH_HOST_OPTIONS=""
     SSH_PRE_COMMAND=""
     SSH_CREDS=""
     if [[ "$ssh_private_key_file" == "none " && "$ssh_password_file" == "none" ]]; then
         log "error" "either a file with the user password or ssh private key file must be set. Ref: ssh_password_file and ssh_private_key_file in onprem.env. exiting..."
         exit 1
     elif [[ "$ssh_private_key_file" != "none " ]] ;then
         SSH_HOST_OPTIONS="-i $ssh_private_key_file"
     elif [[ "$ssh_password_file" != "none" ]] ;then
         SSH_PRE_COMMAND="sshpass -f $ssh_password_file"
     fi

    SSH_CREDS="$ssh_user@$ssh_admin_server_host"

     ## [ SSH JumpHost]
     #ssh_jump_host=129.146.72.166                    # Jumphost IP Address or hostname
     #ssh_jump_host_user=opc                # username to authenticate on SSH Jumphost
     SSH_JUMPHOST_COMMAND=""
     SSH_JUMPHOST_PRE_COMMAND=""
     SSH_JUMPHOST_OPTIONS=""
     SSH_JUMPHOST_CREDS=""
     #ssh_jump_host_password_file=       #/path/to/ssh_jump_host user password_file
     #ssh_jump_host_private_key_file=/path/to/private.key    #/path/to/ssh_jump_host user private_key_file
     ssh_jump_host_password_file=${ssh_jump_host_password_file:-none}
     ssh_jump_host_private_key_file=${ssh_jump_host_private_key_file:-none}
     if [[ "$ssh_jump_host_private_key_file" != "none" ]]; then
         SSH_JUMPHOST_OPTIONS="-i $ssh_jump_host_private_key_file"
     elif [[ "$ssh_jump_host_password_file" != "none" ]]; then
         SSH_JUMPHOST_PRE_COMMAND="sshpass -f $ssh_jump_host_password_file"
     fi
     if [[ "$ssh_jump_host_user@$ssh_jump_host" != "@" ]]; then
           log "info" "jump host set.  $ssh_jump_host"
           SSH_JUMPHOST_CREDS="$ssh_jump_host_user@$ssh_jump_host"
           SSH_PROXY_COMMAND=$(echo -e "$SSH_JUMPHOST_PRE_COMMAND $SSH_JUMPHOST_OPTIONS $SSH_JUMPHOST_CREDS" | sed -e 's/^[[:space:]]*//')
           echo "$SSH_PROXY_COMMAND"
           SSH_JUMPHOST_COMMAND="-o 'ProxyCommand $SSH -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -W %h:%p $SSH_PROXY_COMMAND'"
     fi

     SSH_COMMAND="$SSH_PRE_COMMAND $SSH $SSH_JUMPHOST_COMMAND $SSH_HOST_OPTIONS $SSH_CREDS"
     SSH_COMMAND="$SSH_COMMAND $command"

#      SSH_COMMAND+=($SSH_PRE_COMMAND)
#      SSH_COMMAND+=($SSH)
#      SSH_COMMAND+=($SSH_HOST_OPTIONS)
#      SSH_COMMAND+=("-o")
#      SSH_COMMAND+=("'UserKnownHostsFile /dev/null'")
#      SSH_COMMAND+=("-o")
#      SSH_COMMAND+=("'StrictHostKeyChecking no'")
#      SSH_COMMAND+=($SSH_JUMPHOST_COMMAND)
#      SSH_COMMAND+=($SSH_CREDS)
#      SSH_COMMAND+=($command)
#      SSH_COMMAND+=("date")


#     echo "${SSH_COMMAND[@]}"
      echo $SSH_COMMAND
      uname=$(uname);
      case "$uname" in
          (*Linux*) openCmd='xdg-open'; ;;
          (*Darwin*) bash -c "$SSH_COMMAND" 2>&1 | tee "$LOG_FILE"; ;;
          (*CYGWIN*) openCmd='cygstart'; ;;
          (*) echo 'error: unsupported platform.'; exit 2; ;;
      esac;

#       bash -c "\""${SSH_COMMAND[@]}"\""

#      `$("$SSH_COMMAND")`
# echo "${SSH_COMMAND[@]}"` 2>&1 | tee "$LOG_FILE"
     if [[ $? -eq 1 ]]; then
         log "error" "Failed to run command remotely. Check logs.  exiting..."
         exit 1
     fi
     log "info" "SSH command executed succesfully"
}

secure_copy(){
     source=$1
     destination=$2
     log "info" "Secure Copy file: $source"
     SCP_COMMAND="$SSH_PRE_COMMAND $SECURE_COPY_TOOL $SSH_JUMPHOST_COMMAND $SSH_HOST_OPTIONS $SSH_CREDS:$source $destination"
#     uname=$(uname);
     case "$uname" in
         (*Linux*)  `"$SCP_COMMAND"` 2>&1 | tee "$LOG_FILE"; ;;
         (*Darwin*) bash -c "$SCP_COMMAND" 2>&1 | tee "$LOG_FILE"; ;;
#         (*CYGWIN*) openCmd='cygstart'; ;;
         (*) echo 'error: unsupported platform.'; exit 2; ;;
     esac;
     if [[ $? -eq 1 ]]; then
            log "error" "Failed to run command remotely. Check logs.  exiting..."
            exit 1
     fi
     log "info" "Secure Copy command executed succesfully"
}

export user_functions_loaded=0