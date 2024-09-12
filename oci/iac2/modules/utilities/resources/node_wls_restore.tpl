#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
set -o pipefail

#TEMP_MOUNT_POINT=${temp_oss_mount_point}

function log(){
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    level=$1
    message=$2
#    echo "$timestamp" ["$${level^^}"] "$$message" | tee -a "$LOG_FILE"
    echo "$timestamp" ["$${level^^}"] "$message"
}


function restore_archives() {
    log "info" "Attemting to restore archives..."
    log "info" "Attemting to restore ${domain_archive}"
    sudo su - ${user} -c '/usr/bin/tar -zxf ${temp_oss_mount_point}/${domain_archive} -C /'
    log "info" "Completed restoring ${domain_archive}"
    log "info" "Attemting to restore ${jdk_archive}"
    sudo su - ${user} -c '/usr/bin/tar -zxf ${temp_oss_mount_point}/${jdk_archive} -C /'
    log "info" "Completed restoring ${jdk_archive}"
    log "info" "Attemting to restore ${middleware_archive}"
    sudo su - ${user} -c '/usr/bin/tar -zxf ${temp_oss_mount_point}/${middleware_archive} -C / '
    log "info" "Completed restoring ${middleware_archive}"
    # Restore Custom Archives. Check first if exists.
    sudo su - ${user} -c 'if [ -f ${temp_oss_mount_point}/${custom_archive} ]; then /usr/bin/tar -zxf ${temp_oss_mount_point}/${custom_archive} -C / ;fi '
    log "info" "Completed restoring ${custom_archive}"
    log "info" "Restore completed"
}


time restore_archives || { echo "Error restoring wls archives during startup" 1>&2; exit 1; }


