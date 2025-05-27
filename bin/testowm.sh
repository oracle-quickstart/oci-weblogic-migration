#!/usr/bin/env bash


source ./owm.sh

load_config "$2"

#
discover_local
if [ $? -ne 0 ]; then
  echo "Discover Weblogic failed."
  exit 1
fi

discover_infra_local $DISCOVERED_DOMAIN_JSON

if [ $? -ne 0 ]; then
  echo "Discover infra failed."
  #rm ../out/*.json
  exit 1
fi

process_archives $DISCOVERED_INFRA_JSON

if [ $? -ne 0 ]; then
  echo "Discover infra failed."
  exit 1
fi

upload_to_oci $DISCOVERED_INFRA_JSON "../out"

if [ $? -ne 0 ]; then
  echo "Failed to lift the archive files."
  exit 1
fi

process_datasources $DISCOVERED_INFRA_JSON

if [ $? -ne 0 ]; then
  echo "Failed to discover datasources."
  exit 1
fi

build_orm $DISCOVERED_INFRA_JSON

if [ $? -ne 0 ]; then
  echo "Failed to build the orm bundle."
  exit 1
fi




