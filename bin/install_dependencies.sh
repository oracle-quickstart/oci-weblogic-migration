#!/bin/bash

# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : install_dependencies.sh
# Description          : Install all required dependencies needed to run OCI Weblogic Migration Tool
# Dependencies         : $DEPS_WDT_HOME set in common.sh
#############################################################################################################################


scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.."|| exit; pwd )
LOG_FILE_NAME="owm_install_deps.log"
# echo $scriptPath
# echo $toolHome
over_write_deps=False

[ "$user_functions_loaded" ] || source ./shared.sh


install_jq_release(){
   log "info" "Downloading JQ tool."
   if ! curl -L $JQ_DOWNLOAD_RELEASE_URL -o $DEPS_JQ_HOME/jq >> "$LOG_FILE" 2>&1; then
        log "error" "Failed to downlload and install JQ. Check logs.  exiting..."
        end_section "DEPENDENCIES"
        exit 1
   fi
   chmod +x $DEPS_JQ_HOME/jq
   log "info" "Install and download WDT tool in $DEPS_JQ_HOME completed."
}


install_wdt_release(){
   log "info" "Downloading WDT tool."
   if ! curl -L $WDT_DOWNLOAD_RELEASE_URL | tar xvzf - -C $DEPS_WDT_HOME --strip-components=1>> "$LOG_FILE" 2>&1; then
        log "error" "Failed to downlload and install WDT. Check logs.  exiting..."
        end_section "DEPENDENCIES"
        exit 1
   fi
   log "info" "Install and download WDT tool in $DEPS_WDT_HOME completed."
}

install_deps() {
    local env_name=${1:-".venv"}

#     if [ ! -d "$env_name" ]; then
#         echo "Virtual environment '$env_name' not found. Use '$0 create [env_name]' to create one."
#         return 1
#     else
#        venv_activate_path="./$env_name/bin/activate"
#        source . "${venv_activate_path}"
#     fi

    if [ -f "$toolHome/config/requirements.txt" ]; then
        pip install -r $toolHome/config/requirements.txt
    fi

    if [ -f "$toolHome/config/setup.py" ]; then
        pip install -e $toolHome/config/
    fi

    start_section "DEPENDENCIES"
    if [[ ! -d $DEPS_WDT_HOME ]]; then
        log "info" "$OWLSMIG_NAME dependency directory not configured"
        log "info" "creating WDT dependency directory"
        if [[ $(mkdir -p $DEPS_WDT_HOME) -eq 0 ]]; then
            log "info" "$DEPS_WDT_HOME directory created. "
        else
            log "error" "Failed to create WDT depenency directory. exiting..."
            end_section "DEPENDENCIES"
            exit 1
        fi
    fi
    install_wdt_release


    if [[ ! -d $DEPS_JQ_HOME ]]; then
        log "info" "Creating JQ dependency directory"
        if [[ $(mkdir -p $DEPS_JQ_HOME) -eq 0 ]]; then
            log "info" "$DEPS_JQ_HOME directory created. "
        else
            log "error" "Failed to create JQ depenency directory. exiting..."
            end_section "DEPENDENCIES"
            exit 1
        fi
    fi

#    if [[ "$(ls -A $DEPS_JQ_HOME)" && $over_write_deps ]]; then
    install_jq_release

    end_section "DEPENDENCIES"
}

log "info" "$toolHome" ;
log "info" "Executing $OWLSMIG_NAME";
install_deps venv;





