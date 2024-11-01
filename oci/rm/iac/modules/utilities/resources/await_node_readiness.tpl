#!/bin/bash

#${await_node_readiness}
#${expected_node_count}

while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
  echo -e "\033[1;36mWaiting for cloud-init..."
  sleep 1
done