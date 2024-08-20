#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091 # Ignore unresolved file path present on base images
set -o pipefail

#PORTS="${managed_server_ports}"
PORTS=["9090","7003","9002"]

function log(){
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    level=$1
    message=$2
#    echo "$timestamp" ["${level^^}"] "$message" | tee -a "$LOG_FILE"
    echo "$timestamp" ["${level^^}"] "$message"
}

function run_wls_init() { # Initialize wls worker node
   if [[ -f /etc/systemd/system/wls-init.service ]]; then

   fi
#  if [[ -f /etc/systemd/system/wls-init.service ]]; then
#    systemctl --no-block enable --now wls-init.service
#  elif [[ -f /etc/wls/wls-functions.sh ]] && [[ -f /etc/wls/wls-install.sh ]]; then
#    source /etc/wls/wls-functions.sh
#    local apiserver_host; apiserver_host=$(get_apiserver_host)
#    if [[ -z "${apiserver_host}" ]]; then
#      apiserver_host=$(get_imds_metadata | jq -rcM '.apiserver_host')
#    fi
#
#    cluster_ca=$(get_kubelet_client_ca)
#    if [[ -z "${cluster_ca}" ]]; then
#      cluster_ca=$(get_imds_metadata | jq -rcM '.cluster_ca_cert')
#    fi
#
#    bash /etc/wls/wls-install.sh \
#      --apiserver-endpoint "${apiserver_host}" \
#      --kubelet-ca-cert "${cluster_ca}"
#  else # Retrieve base64-encoded script content from http, e.g. instance metadata
#    local wls_init_url='http://169.254.169.254/opc/v2/instance/metadata/wls_init_script'
#    curl --fail -H "Authorization: Bearer Oracle" -L0 "${wls_init_url}" \
#      | base64 --decode >/var/run/wls-init.sh && bash /var/run/wls-init.sh
#  fi
  log "info" "Opening firewalld ports"
  for port in "${PORTS[@]}"; do
      log "info" "Running firewall-offline-cmd --add-port=$port/tcp"
      if ! firewall-offline-cmd --add-port="$port"/tcp >> "$LOG_FILE" 2>&1; then
          log "error" "Failure opening port $port"
          FAILURE='true'
      fi
  done
}

time run_wls_init || { echo "Error in wls startup" 1>&2; exit 1; }