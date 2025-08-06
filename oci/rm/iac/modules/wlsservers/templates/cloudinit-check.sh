#!/bin/bash
# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

set -e

dump_cloud_init_error_logs() {
  if [ -f /var/log/owm/cloud-init-errors.log ]; then
    cat /var/log/owm/cloud-init-errors.log
  fi
}

if cloud-init status --wait; then
  dump_cloud_init_error_logs
  echo "$(hostname): Cloud-init Completed Successfully"
else
  echo "======= Cloud-init Error Summary of the host: $(hostname) ======="
  awk '/<ERROR>|Traceback|Exception/ { print_line = 1 } print_line { print } /^$|^.*INFO.*$|^.*DEBUG.*$/ { print_line = 0 }' /var/log/cloud-init-output.log
  dump_cloud_init_error_logs
  echo -e "\nRefer to /var/log/cloud-init-output.log and /var/log/owm/*.log for more details."
  echo "======= End of Error Summary of the host: $(hostname) ======="
  exit 1
fi
