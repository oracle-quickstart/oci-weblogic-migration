#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
#set -o pipefail
set -Eeuo pipefail

function __error_handing__(){
    local last_status_code=$1;
    local error_line_number=$2;
    echo 1>&2 "Error - exited with status $last_status_code at line $error_line_number" | log >> $log_file
    perl -slne 'if($.+5 >= $ln && $.-4 <= $ln){ $_="$. $_"; s/$ln/">" x length($ln)/eg; s/^\D+.*?$/\e[1;31m$&\e[0m/g;  print}' -- -ln=$error_line_number $0 | log >> $log_file
}

trap  '__error_handing__ $? $LINENO' ERR

#USER=${user}

fileName=$(basename $BASH_SOURCE)

function get_logs_dir {
  response_code=$(curl  --write-out '%%{http_code}' --silent --output /dev/null -H "Authorization:Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/logs_dir)
  if [[ "$response_code" -eq 200 ]] ; then
     logs_dir=$(curl -H "Authorization:Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/logs_dir)
     echo $logs_dir
  else
     logs_dir=$(curl -L http://169.254.169.254/opc/v1/instance/metadata/logs_dir)
     echo $logs_dir
  fi
}

logs_dir=`get_logs_dir`
mkdir -p $${logs_dir}
log_file="$${logs_dir}/wls-restore.log"


function log(){
    while IFS= read -r line; do
            DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
            echo "<$DATE>  $line"
    done
}

function check_fs(){
   echo "<cloud-init><restore><check_fs> list volumes prior restoring" | log >> $log_file
   ls  ${jdk_device_id} && ls ${mw_device_id} && ls ${domain_device_id}
   exit_code=$?
   echo "list devices returned with exit code $[exit_code] " | log >> $log_file
   if [[ $exit_code -ne 0 ]]; then
     echo "<cloud-init><restore><check_fs> volumes not mounted attempting to format and mount again" | log >> $log_file
     mkfs.xfs -f ${jdk_device_id}
     mkfs.xfs -f ${mw_device_id}
     mkfs.xfs -f ${domain_device_id}
     mount -a
     echo "<cloud-init><restore><check_fs> volumes not mounted and created outside cloud-init" | log >> $log_file
   fi

}

function set_fs_ownership() {
    echo "<cloud-init><set_fs_ownership> Setting ownership to ${user} on mounted volumes" | log >> $log_file
    chown -R ${user}:${group} ${block_volume_domain_mountpath}
    exit_code=$?
    echo "<cloud-init><set_fs_ownership> change ownership on mount point ${block_volume_domain_mountpath} returned with exit code $[exit_code] " | log >> $log_file
    chown -R ${user}:${group} ${block_volume_mw_mountpath}
    exit_code=$?
    echo "<cloud-init><set_fs_ownership> change ownership on mount point ${block_volume_mw_mountpath} returned with exit code $[exit_code] " | log >> $log_file
    chown -R ${user}:${group} ${block_volume_jdk_mountpath}
    exit_code=$?
    echo "<cloud-init><set_fs_ownership> change ownership on mount point ${block_volume_jdk_mountpath} returned with exit code $[exit_code] " | log >> $log_file
    if [ $exit_code -ne 0 ]; then
        echo "<cloud-init><set_fs_ownership><error> Failed to change ownership. Exiting with [$exit_code] " | log >> $log_file
        exit 1
    fi
    echo "<cloud-init><set_fs_ownership> change ownership completed" | log >> $log_file
}

check_fs
set_fs_ownership;
output=$(sudo -u ${user} -E python /opt/scripts/restore-archives.py)
exit_code=$?
echo $output | log >> $log_file
if [[ $exit_code -ne 0 ]]; then
  echo "<cloud-init><restore><ERROR> Failed to restore WebLogic Archives " | log >> $log_file
  exit 1
fi
echo "Executed restore-archives via ${user} with exit code [$exit_code]" | log >> $log_file
echo "<cloud-init><restore_archives> Restore completed" | log >> $log_file

