#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
set -o pipefail

#TEMP_MOUNT_POINT=${temp_oss_mount_point}
#BUCKET_NAME=${bucket_name}
#USER=${user}

function log(){
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    level=$1
    message=$2
#    echo "$timestamp" ["$${level^^}"] "$$message" | tee -a "$LOG_FILE"
    echo "$timestamp" ["$${level^^}"] "$message"
}


function configure_ocifs(){
  log "info" "Checking if ocifs is installed"
  log "info" "Running rpm -qa | grep -q ocifs"
  if ! rpm -qa | grep -i ocifs; then
      log "error" "ocifs is not installed - will not mount OCI Object Storage systems"
      FAILURE='true'
  else
      log "info" "OCIFS installed - configuring mount point OCI file systems"
      su -c 'mkdir -p ${temp_oss_mount_point}' - ${user}
      if ! su -c '/usr/bin/ocifs --auth=instance_principal ${bucket_name} ${temp_oss_mount_point}' - ${user} ; then
          log "error" "Failed to mount OCI OSS bucket"
          FAILURE='true'
      fi
  fi
}

time configure_ocifs || { echo "Error configuring ocifs in startup" 1>&2; exit 1; }

function restore_archives() {
    log "info" "Attemting to restore archives..."
    chown -R ${user}:${group} ${block_volume_domain_mountpath}
    chown -R ${user}:${group} ${block_volume_mw_mountpath}
    chown -R ${user}:${group} ${block_volume_jdk_mountpath}
}


time restore_archives || { echo "Error restoring wls archives during startup" 1>&2; exit 1; }