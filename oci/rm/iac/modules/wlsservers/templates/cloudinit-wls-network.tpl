#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
set -o pipefail

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
log_file="$${logs_dir}/network-ports.log"
error_log_file="$${logs_dir}/cloud-init-errors.log"

function log() {
    while IFS= read -r line; do
        DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
        echo "<$DATE>  $line"
    done
}

function run_wls_init() { # Initialize wls worker node
#  if [[ -f /etc/systemd/system/wls-init.service ]]; then
#    systemctl --no-block enable --now wls-init.service
 enabled_weblogic_ports;
 install_required_libraries;
 configure_coherence_ports;
}

function enabled_weblogic_ports(){
  local method="enabled_weblogic_ports"
  echo "<cloudinit-wls-network><$method>Opening firewalld ports" | log >> $log_file

     %{ for port in ports ~}
       echo "<cloudinit-wls-network><$method>Running firewall-offline-cmd --add-port=${port}/tcp" | log >> $log_file
       if ! firewall-offline-cmd --add-port="${port}"/tcp ; then
                 echo "<cloudinit-wls-network><$method><ERROR>Failure opening port ${port}" | log | tee -a $log_file >> $error_log_file
                 FAILURE='true'
       fi
     %{ endfor ~}
}

function install_required_libraries() {
  local method="install_required_libraries"
  os_version=$(grep ^VERSION= /etc/os-release | cut -d'"' -f2 | cut -d"." -f1)
  if [[ "$os_version" == "7" ]]; then
      echo "<cloudinit-wls-network><$method>Installing compat-libstdc++-33" | log >> $log_file
      if ! yum install -y  compat-libstdc++-33 ; then
          echo "<cloudinit-wls-network><$method><ERROR>Failed to install compat-libstdc++-33" | log | tee -a $log_file >> $error_log_file
          FAILURE='true'
      fi
  fi
  echo "<cloudinit-wls-network><$method><exit>" | log >> $log_file
}

function configure_coherence_ports() {
  local method="configure_coherence_ports"
  echo "<cloudinit-wls-network><$method>Opening Coherence fixed ports 32768-60999 tcp and udp" | log >> $log_file
  echo "<cloudinit-wls-network><$method>Running firewall-offline-cmd --add-port=32768-60999/tcp" | log >> $log_file
  if ! firewall-offline-cmd --add-port=32768-60999/tcp ; then
      echo "<cloudinit-wls-network><$method><ERROR>Failure opening tcp ports 32768-60999" | log | tee -a $log_file >> $error_log_file
      FAILURE='true'
  fi
  echo "<cloudinit-wls-network><$method>Running firewall-offline-cmd --add-port=32768-60999/udp" | log >> $log_file
  if ! firewall-offline-cmd --add-port=32768-60999/udp ; then
      echo "<cloudinit-wls-network><$method><ERROR>Failure opening udp ports 32768-60999" | log | tee -a $log_file >> $error_log_file
      FAILURE='true'
  fi

  echo "<cloudinit-wls-network><$method>Opening Coherence fixed tcp port 7" | log >> $log_file
  echo "<cloudinit-wls-network><$method>Running firewall-offline-cmd --add-port=7/tcp" | log >> $log_file
  if ! firewall-offline-cmd --add-port=7/tcp ; then
      echo "<cloudinit-wls-network><$method><ERROR>Failure opening tcp ports 7" | log | tee -a $log_file >> $error_log_file
      FAILURE='true'
  fi

  echo "<cloudinit-wls-network><$method>Restarting firewalld" | log >> $log_file
  if ! systemctl restart firewalld ; then
      echo "<cloudinit-wls-network><$method><ERROR>Failed restarting firewalld" | log | tee -a $log_file >> $error_log_file
      FAILURE='true'
  fi

  echo "<cloudinit-wls-network><$method>Restarting firewalld" | log >> $log_file
  if ! systemctl restart firewalld ; then
      echo "<cloudinit-wls-network><$method><ERROR>Failed restarting firewalld" | log | tee -a $log_file >> $error_log_file
      FAILURE='true'
  fi
  echo "<cloudinit-wls-network><$method><exit>" | log >> $log_file
}



time run_wls_init || { echo "Error in wls startup" | log >> $log_file 1>&2; exit 1; }