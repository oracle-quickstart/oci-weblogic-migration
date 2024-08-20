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

function run_wls_init() { # Initialize wls worker node
#  if [[ -f /etc/systemd/system/wls-init.service ]]; then
#    systemctl --no-block enable --now wls-init.service
#  elif [[ -f /etc/wls/wls-functions.sh ]] && [[ -f /etc/wls/wls-install.sh ]]; then
#    source /etc/wls/wls-functions.sh
#    local apiserver_host; apiserver_host=$$(get_apiserver_host)
#    if [[ -z "$${apiserver_host}" ]]; then
#      apiserver_host=$$(get_imds_metadata | jq -rcM '.apiserver_host')
#    fi
#
#    cluster_ca=$$(get_kubelet_client_ca)
#    if [[ -z "$${cluster_ca}" ]]; then
#      cluster_ca=$$(get_imds_metadata | jq -rcM '.cluster_ca_cert')
#    fi
#
#    bash /etc/wls/wls-install.sh \
#      --apiserver-endpoint "$${apiserver_host}" \
#      --kubelet-ca-cert "$${cluster_ca}"
#  else # Retrieve base64-encoded script content from http, e.g. instance metadata
#    local wls_init_url='http://169.254.169.254/opc/v2/instance/metadata/wls_init_script'
#    curl --fail -H "Authorization: Bearer Oracle" -L0 "$${wls_init_url}" \
#      | base64 --decode >/var/run/wls-init.sh && bash /var/run/wls-init.sh
#  fi
 enabled_weblogic_ports;
 install_required_libraries;
 configure_coherence_ports;
 configure_ocifs;
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


time run_wls_init || { echo "Error in wls startup" 1>&2; exit 1; }