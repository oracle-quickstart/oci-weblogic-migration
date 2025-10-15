#!/usr/bin/env bash
# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
set -o pipefail

#TEMP_MOUNT_POINT=${temp_oss_mount_point}
#BUCKET_NAME=${bucket_name}
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
log_file="$${logs_dir}/configure_ocifs.log"
error_log_file="$${logs_dir}/cloud-init-errors.log"

function log(){
    while IFS= read -r line; do
            DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
            echo "<$DATE>  $line"
    done
}

function configure_ocifs(){
  echo "<cloud-init><configure_ocifs><init> Checking if ocifs is installed" | log >> $log_file
  echo "<cloud-init><configure_ocifs> Running rpm -qa | grep -q ocifs" | log >> $log_file
  output=$(rpm -qa | grep -i ocifs 2>&1)
  exit_code=$?
  echo $output | log >> $log_file
  if [ $exit_code -ne 0 ]; then
      echo "<cloud-init><configure_ocifs> ocifs not installed via cloud-init. Attempting to install manually 3 times."
      for i in $(seq 1 30)
      do
          osms check 2>&1
          if [[ $? != 0 ]]
          then
              # Failed
              echo "."
              sleep 1s
          else
              # worked!
              yum -y install ocifs 2>&1
              exit_code=$?
              echo "yum install ocifs exited with code [$exit_code]" | log >> $log_file
              break
          fi
      done
  else
      echo "<cloud-init><configure_ocifs> OCIFS installed - configuring access via instance_principal to ${bucket_name}" | log >> $log_file
      output=$(su -c 'mkdir -p ${temp_oss_mount_point} 2>&1' - ${user})
      exit_code=$?
      echo $output | log >> $log_file
      if [ $exit_code -eq 0 ]; then
        echo "<cloud-init><configure_ocifs> created mount point ${temp_oss_mount_point}" | log >> $log_file
      else
        echo "Failed to create mount point [${temp_oss_mount_point}]. Exiting with [$exit_code]" | log | tee -a $log_file >> $error_log_file
        echo "$output" | log >> $error_log_file
        #clean up script
        #/opt/scripts/tidyup.sh
        exit 1
      fi
      output=$(su -c '/usr/bin/ocifs --auth=instance_principal ${bucket_name} ${temp_oss_mount_point} 2>&1' - ${user})
      echo $output | log >> $log_file
      sleep 10 # need to wait for service to warm up cache.. it may take time based on number of files.
      output=$(su -c 'ls ${temp_oss_mount_point} 2>&1' - ${user})
      echo $output | log >> $log_file
      if [ $exit_code -ne 0 ]; then
        echo  "Failed to mount OCI OSS bucket with [$exit_code] exiting..." | log | tee -a $log_file >> $error_log_file
        echo "$output" | log >> $error_log_file
        exit 1
      fi
  fi
}

configure_ocifs;



function set_fs_ownership() {
    echo "<cloud-init><set_fs_ownership> Setting ownership to ${user} on mounted volumes" | log >> $log_file
    chown -R ${user}:${group} ${block_volume_domain_mountpath}
    chown -R ${user}:${group} ${block_volume_mw_mountpath}
    output=$(chown -R ${user}:${group} ${block_volume_jdk_mountpath} 2>&1)
    echo $output | log >> $log_file
    if [ $exit_code -ne 0 ]; then
      echo "<cloud-init><set_fs_ownership><error> Failed to change ownership. Exiting with [$exit_code] " | log | tee -a $log_file >> $error_log_file
      echo "$output" | log >> $error_log_file
      exit 1
    fi
    echo "<cloud-init><set_fs_ownership> change ownership completed" | log >> $log_file
}

set_fs_ownership;

