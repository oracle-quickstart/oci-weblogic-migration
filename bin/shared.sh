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


readonly OWLSMIG_NAME="OCI Weblogic Migration Tool"
DEPS_DIR=$toolHome/deps
readonly DEPS_WDT_HOME=$DEPS_DIR/wdt
readonly DEPS_JQ_HOME=$DEPS_DIR/jq
readonly DEPS_OCI_SDK_HOME=$DEPS_DIR/oci
readonly LOG_DIR=$toolHome/logs
LOG_FILE="$LOG_DIR/$LOG_FILE_NAME"
readonly WDT_DOWNLOAD_RELEASE_URL="https://github.com/oracle/weblogic-deploy-tooling/releases/download/release-4.3.5/weblogic-deploy.tar.gz"
readonly JQ_DOWNLOAD_RELEASE_URL="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
readonly OCI_JAVA_SDK_DOWNLOAD_RELEASE_URL="https://github.com/oracle/oci-java-sdk/releases/download/v3.49.0/oci-java-sdk-3.49.0.zip"
readonly REPO_ARCHIVE_PATH=${3:-$toolHome/out}

readonly SSH=/usr/bin/ssh
readonly SECURE_COPY_TOOL=/usr/bin/scp

# Control RETURN codes
readonly SUCCESS=0
readonly FAIL=1
readonly OP_COMPLETED=2
readonly OP_INCOMPLETE=3
readonly VAR_SET=4
#TODO: Set variable definition.
#PRIV_SSH_KEY_PATH="/home/opc/.ssh/dlp_common"
#"${PRIV_SSH_KEY_PATH:?Variable not set or empty}"
#readonly INVENTORY_FILE='wlsdomain.json'



# shellcheck disable=SC2112
function start_section() {
    # printf "    Checking %s requirements... \n" "$1"
    message="start section $1"
    log_section="$1"
    log "info" "$message" "<$1>"
}

# shellcheck disable=SC2112
function end_section() {
    message="end section $1"
    log "info" "$message" "<$1>"
    unset log_section
}

# shellcheck disable=SC2112
function log(){
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    level=$1
    message=$2
    section=${3:-$log_section}
    shopt -s nocasematch
    if [[ "${OMT_LOG_LEVEL}" == "TRACE" && "${level}" == "DEBUG" ]]; then
        echo "$timestamp" "$section" ["DEBUG"] "$message" | tee -a "$LOG_FILE"
    elif [[ "${level}" != "DEBUG" ]]; then
        echo "$timestamp" "$section" ["${level}"] "$message" | tee -a "$LOG_FILE"
    fi

    #echo "$timestamp" "$section" ["${level^^}"] "$message"  | tee /dev/fd/3
    #exec 3>&1 1>"$LOG_FILE" 2>&1
}

update_migration_data_json() {
  #Creating & updating migration_data.json, a metadata json file using jq tool.

  local key=$1
  local value=$2
  local MIGRATION_DATA_JSON="$toolHome/logs/migration_data.json"
  local MIGRATION_SCRIPT_LOG="$toolHome/logs/migration_script.log"

  # Creating file with empty JSON object if it doesn't exist or if it an empty file.
  if [ ! -f "$MIGRATION_DATA_JSON" ] || [ ! -s "$MIGRATION_DATA_JSON" ]; then
    echo '{}' > "$MIGRATION_DATA_JSON"
  fi

  # Check if JSON metadata file is invalid or corrupted.
  if ! jq empty "$MIGRATION_DATA_JSON" >/dev/null 2>>"$MIGRATION_SCRIPT_LOG"; then
    log "error" "The metadata file [$MIGRATION_DATA_JSON] is invalid or corrupted."
    log "error" "Refer to the README.md for recovery steps, or manually delete the metadata file [$MIGRATION_DATA_JSON] and contents of [$toolHome/out] before re-running migration_script.sh"
    log "error" "Migration failed."
    exit 1
  fi

  # Creating a temporary file safely in the logs directory.
  local tmpfile
  tmpfile=$(mktemp "$toolHome/logs/tmp.XXXXXX") || {
    log "error" "Failed to create temporary file in $toolHome/logs/  . See $MIGRATION_SCRIPT_LOG for details." >> "$MIGRATION_SCRIPT_LOG"
    log "error" "Run migration_script.sh again after resolving the issue."
    log "error" "Migration failed."
    exit 1
  }

  # Updating the key in the JSON file, moving the output in tmpfile.
  if ! jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$MIGRATION_DATA_JSON" > "$tmpfile" 2>>"$MIGRATION_SCRIPT_LOG"; then
    log "error" "jq failed while updating key [$key] in $MIGRATION_DATA_JSON. See $MIGRATION_SCRIPT_LOG for details."
    log "error" "Run migration_script.sh again after resolving the issue."
    rm -f "$tmpfile"
    log "error" "Migration failed."
    exit 1
  fi

  # Moving back the out
  if ! mv "$tmpfile" "$MIGRATION_DATA_JSON"; then
    log "error" "Failed to overwrite $MIGRATION_DATA_JSON with updated data. Check write permissions."
    log "error" "Run migration_script.sh again after resolving the issue."
    rm -f "$tmpfile"
    log "error" "Migration failed."
    exit 1
  fi
}

is_empty_dir() {
    log "info" "is_empty_dir $1"
    # [[ "*..." = "$(printf %s * .*)" ]];
    # shellcheck disable=SC2046
    return $(find $1 -maxdepth 0 -empty)
}

load_config(){
  config_file=${1:?"first argument must be a environment configuration file.  i.e. ../config/on-prem.env"} || return $?
  log "info" "loading OnPrem configuration $config_file"
  [ ! -f "$1" ] || export $(sed 's/#.*//g' "$config_file" | xargs)
  log "info" "Properties loaded $config_file"
}

init_ssh_session(){
  echo "<shared><init_ssh_session><entry>"
  # Check required flags are set
         # Need SSH credentials
         # Need Admin Console URL with user and password file
         # ssh_admin_server_host=12.0.0.215           # Weblogic Server Admin IP or hostname.
           #ssh_user=domain                  # Operating system user with permissions to read
           #ssh_password_file=                 #/path/to/file_with_ssh_password
           #ssh_private_key_file=/Users/JOI/Documents/OCI/keys/mykey              #/path/to/private_key_file
           #oracle_home=/opt/middleware        #set to ORACLE_HOME in local Linux Server.
           #jdk_home=                          # set to JDK path in local Linux Server.
           #node_manager_home=                # set the node_manager_home if Weblogic Deployment Type is Node Manager per Machine.
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
       if [[ -f $ssh_private_key_file &&  -f $ssh_password_file ]]; then
         echo "file with the user password (ssh_password_file) or ssh private key file (ssh_private_key_file) must be set.  exiting.."
         exit 1
       fi
       if [[ "$ssh_private_key_file" == "none" && "$ssh_password_file" == "none" ]]; then
           log "error" "either a file with the user password or ssh private key file must be set. Ref: ssh_password_file and ssh_private_key_file in onprem.env. exiting..."
           echo "<shared><init_ssh_session><error> neither privatey_key_file or ssh_password_file was set. "
           exit 1
       elif [[ "$ssh_private_key_file" != "none " ]] ;then
           SSH_HOST_OPTIONS="-i $ssh_private_key_file"
       elif [[ "$ssh_password_file" != "none" ]] ;then
           SSH_PRE_COMMAND="sshpass -f $ssh_password_file"
       fi

      SSH_CREDS="$ssh_user@$ssh_admin_server_host"
      echo "<shared><init_ssh_session><credentials> checked"
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
  #           echo "$SSH_PROXY_COMMAND"
             SSH_JUMPHOST_COMMAND="-o 'ProxyCommand $SSH -E $toolHome/logs/ssh_jumphost.log -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -W %h:%p $SSH_PROXY_COMMAND'"
       fi
       SSH_COMMAND="$SSH_PRE_COMMAND $SSH -E $toolHome/logs/ssh.log $SSH_JUMPHOST_COMMAND $SSH_HOST_OPTIONS $SSH_CREDS"
#       SSH_COMMAND="$SSH_COMMAND $command"
       SSH_COMMAND="$SSH_COMMAND WLSDEPLOY_PROPERTIES=-Dwlsdeploy.debugToStdout=true $command"
       echo "<shared><init_ssh_session><exit>  $SSH_COMMAND"
}

function run_piped_ssh_command(){
   echo "<shared><run_piped_ssh_command><entry> $*"
   output_file=${1:?"output file not defined. exiting..."} || return $?
   shift
   command="$@"
   init_ssh_session
   uname=$(uname);
       case "$uname" in
           (*Linux*) bash -c "$SSH_COMMAND" ;;
           (*Darwin*) bash -c "$SSH_COMMAND" > $output_file;;
   #        (*CYGWIN*) openCmd='cygstart'; ;;
           (*) echo 'error: unsupported platform.'; exit 2; ;;
       esac;

      if [[ $? -eq 1 ]]; then
          log "error" "Failed to run command remotely. Check logs.  exiting..."
          exit 1
      fi
      log "info" "SSH command executed successfully"
}

run_ssh_command(){
     command="$@"
     log "info" "Running Remote command: $command"
     init_ssh_session
     uname=$(uname);
    case "$uname" in
        (*Linux*) `"$SCP_COMMAND"` 2>&1 | tee "$LOG_FILE"; ;;
        (*Darwin*) bash -c "$SSH_COMMAND" 2>&1 | tee "$LOG_FILE"; ;;
#        (*CYGWIN*) openCmd='cygstart'; ;;
        (*) echo 'error: unsupported platform.'; exit 2; ;;
    esac;

     if [[ $? -eq 1 ]]; then
         log "error" "Failed to run command remotely. Check logs.  exiting..."
         exit 1
     fi
     log "info" "SSH command executed successfully"
}

# Construct SSH authentication arguments based on available config values.
# Priority: private key (with optional passphrase) > password file.
get_ssh_args() {
  local ssh_args=""
  [[ -n "$ssh_user" ]] && ssh_args="$ssh_args -ssh_user $ssh_user"
  if [[ -n "$ssh_private_key_file" && -f "$ssh_private_key_file" ]]; then
    ssh_args="$ssh_args -ssh_private_key $ssh_private_key_file"
    if [[ -n "$ssh_private_key_pass_file" && -f "$ssh_private_key_pass_file" ]]; then
      ssh_args="$ssh_args -ssh_private_key_pass_file $ssh_private_key_pass_file"
    fi
  elif [[ -n "$ssh_password_file" && -f "$ssh_password_file" ]]; then
    ssh_args="$ssh_args -ssh_pass_file $ssh_password_file"
  fi
  echo "$ssh_args"
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
     log "info" "Secure Copy command executed successfully"
}

log_exit_attempt(){
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

user_functions_loaded=0