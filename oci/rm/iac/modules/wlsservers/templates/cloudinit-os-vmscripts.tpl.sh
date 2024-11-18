#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
set -E -o functrace

trap '>&2 echo Command failed: $(tail -n+$LINENO $0 | head -n1)' ERR

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
log_file="$${logs_dir}/os-vmscripts.log"


function log(){
    while IFS= read -r line; do
            DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
            echo "<$DATE>  $line"
    done
}

mkdir -p /opt/scripts
chown -R ${user}: /opt/scripts
exit_code=$?
echo "Executed change ownership of /opt/scripts to ${user} with exit code [$exit_code]" | log >> $log_file

#vmscripts_file=wlsoci-vmscripts.zip  oss_mount_point restore_path=/
output=$(sudo -u ${user} -E unzip "${oss_mount_point}/${vmscripts_file}" -d "${restore_path}")
exit_code=$?
echo $output | log >> $log_file
echo "Executed unzip ${vmscripts_file} via ${user} with exit code [$exit_code]" | log >> $log_file
if [ $exit_code -ne 0 ]; then
    echo  "<cloud-init-os-vmscripts><init><ERROR> vmscripts could not be restored" | log >> $log_file
    return 1
fi
echo  "<cloud-init-os-vmscripts><init><exit>" | log >> $log_file
