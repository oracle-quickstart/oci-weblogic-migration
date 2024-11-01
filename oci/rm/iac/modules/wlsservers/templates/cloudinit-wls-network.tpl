#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091
set -o pipefail

function log(){
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    level=$1
    message=$2
    echo "$timestamp" ["$${level^^}"] "$message"
}

function run_wls_init() { # Initialize wls worker node
#  if [[ -f /etc/systemd/system/wls-init.service ]]; then
#    systemctl --no-block enable --now wls-init.service
#  elif [[ -f /etc/wls/wls-functions.sh ]] && [[ -f /etc/wls/wls-install.sh ]]; then
#    source /etc/wls/wls-functions.sh
#  else # Retrieve base64-encoded script content from http, e.g. instance metadata
#    local wls_init_url='http://169.254.169.254/opc/v2/instance/metadata/wls_init_script'
#    curl --fail -H "Authorization: Bearer Oracle" -L0 "$${wls_init_url}" \
#      | base64 --decode >/var/run/wls-init.sh && bash /var/run/wls-init.sh
#  fi
 enabled_weblogic_ports;
 install_required_libraries;
 configure_coherence_ports;
}

function enabled_weblogic_ports(){
  log "info" "Opening firewalld ports"

     %{ for port in ports ~}
       log "info" "Running firewall-offline-cmd --add-port=${port}/tcp"
       if ! firewall-offline-cmd --add-port="${port}"/tcp ; then
                 log "error" "Failure opening port ${port}"
                 FAILURE='true'
       fi
     %{ endfor ~}
}

function install_required_libraries() {
  os_version=$(grep ^VERSION= /etc/os-release | cut -d'"' -f2 | cut -d"." -f1)
  if [[ "$os_version" == "7" ]]; then
      log "info" "Installing compat-libstdc++-33"
      if ! yum install -y  compat-libstdc++-33 ; then
          log "error" "Failed to install compat-libstdc++-33"
          FAILURE='true'
      fi
  fi
}

function configure_coherence_ports() {
  log "info" "Opening Coherence fixed ports 32768-60999 tcp and udp"
  log "info" "Running firewall-offline-cmd --add-port=32768-60999/tcp"
  if ! firewall-offline-cmd --add-port=32768-60999/tcp ; then
      log "error" "Failure opening tcp ports 32768-60999"
      FAILURE='true'
  fi
  log "info" "Running firewall-offline-cmd --add-port=32768-60999/udp"
  if ! firewall-offline-cmd --add-port=32768-60999/udp ; then
      log "error" "Failure opening udp ports 32768-60999"
      FAILURE='true'
  fi

  log "info" "Opening Coherence fixed tcp port 7"
  log "info" "Running firewall-offline-cmd --add-port=7/tcp"
  if ! firewall-offline-cmd --add-port=7/tcp ; then
      log "error" "Failure opening tcp ports 7"
      FAILURE='true'
  fi

  log "info" "Restarting firewalld"
  if ! systemctl restart firewalld ; then
      log "error" "Failed restarting firewalld"
      FAILURE='true'
  fi

  log "info" "Restarting firewalld"
  if ! systemctl restart firewalld ; then
      log "error" "Failed restarting firewalld"
      FAILURE='true'
  fi
}



time run_wls_init || { echo "Error in wls startup" 1>&2; exit 1; }