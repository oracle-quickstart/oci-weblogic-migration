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

output=$(sudo -u ${user} -E python /opt/scripts/restore-archives.py)
exit_code=$?
echo $output | log >> $log_file
if [[ $exit_code -ne 0 ]]; then
  echo "<cloud-init><restore><ERROR> Failed to restore WebLogic Archives " | log >> $log_file
  exit 1
fi
echo "Executed restore-archives via ${user} with exit code [$exit_code]" | log >> $log_file
echo "<cloud-init><restore_archives> Restore completed" | log >> $log_file

