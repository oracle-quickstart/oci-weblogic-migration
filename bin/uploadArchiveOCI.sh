#!/usr/bin/env bash

# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

set -o pipefail

scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.."; pwd)
LOG_FILE="$toolHome/logs/upload_to_oci_archive.log"

[ "$user_functions_loaded" ] || source ./shared.sh



function pre-reqs(){
    local oci_bucket_name=$1
    local oci_compartment_id=$2
    log "info" "<uploadArchiveOCI><pre-reqs><entry> Args: $oci_bucket_name and $oci_compartment_id"
    if ! oci iam region list >> "$LOG_FILE" 2>&1; then
        log "error" "Fail to verify OCI cli is configured. For more information visit: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
        log "error" "exiting..."
        exit 1
    fi
    log "info" "<uploadArchiveOCI><pre-reqs> oci cli tool seemed configured."
    log "debug" " about to run command : oci os bucket get --bucket-name "$oci_bucket_name""
    if ! oci os bucket get --bucket-name "$oci_bucket_name" >> "$LOG_FILE" 2>&1; then
        log "error" "bucket does not exist. Attempting to create bucket..."
        log "debug" " about to run command : oci os bucket create --name "$oci_bucket_name" --compartment-id "$oci_compartment_id""
        if ! oci os bucket create --name "$oci_bucket_name" --compartment-id "$oci_compartment_id" >> "$LOG_FILE" 2>&1; then
            log "error" "Failed to create bucket. Check OCI credentials. Exiting..."
            exit 1
        fi
        log "info" "<uploadArchiveOCI><pre-reqs> Bucket created."
    fi
    log "info" "<uploadArchiveOCI><pre-reqs><exit> "
}

upload_to_oss(){
    return_code=0
    log "info" "<uploadArchiveOCI><upload_to_oss><entry> Args:  $1 $2 $3"
    local INVENTORY_FILE=$1
    local REPO_DIRECTORY=$2
    local REPO_PATH=${3:-$toolHome/out}
    local REPO="$REPO_PATH/$REPO_DIRECTORY"
    compartment_ocid=${compartment_ocid:?"output file not passed must exit. exiting..."} || return $?
    bucket_name=${bucket_name:?"a bucket name is required. Check configuration file. exiting..."} || return $?
    tenancy_namespace=${tenancy_namespace:?"OCI tenancy_namespace is required. ref: https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/understandingnamespaces.htm. exiting..."} || return $?
    log "info" "Starting tool to upload WLS Archives to Oracle Cloud Infrastructure Object Storage"
    log "debug" "Namespace: $tenancy_namespace"
    log "debug" "Bucket: $bucket_name"
    log "debug" "repo: $REPO"
    domain_name=$(jq --raw-output -c '.topology.Name' "$INVENTORY_FILE")
    pre-reqs "$bucket_name" "$compartment_ocid"
    shopt -s nullglob  # expand globs to nothing if no match
    for machine in $(jq --raw-output -c '.resources.Machines|keys[]' "$INVENTORY_FILE"); do
        log "debug" "machine: $machine"
        for f in "$REPO/$machine"*;
        do
            [[ -e "$f" ]] || break
            log "info" "<uploadArchiveOCI><upload_to_oss> uploading archive $f"
            oci os object put --namespace "$tenancy_namespace" --bucket-name "$bucket_name" --file "$f" --force >> "$LOG_FILE" || (log "error" "failed to upload $f ... exiting" ; exit 1)
        done
        return_code=$OP_COMPLETED
    done
    return "$return_code"
}

update_oss_auto_tfvars(){
   log "info" "<uploadArchiveOCI><update_oss_auto_tfvars><entry>"
   stack_path="$toolHome/oci/iac/overlay/wls-migrate-inventory"
   bucket_name=${bucket_name:?"a bucket name is required. Check configuration file. exiting..."} || return $?
   log "info" "<uploadArchiveOCI><update_oss_auto_tfvars> creating oss.auto.tfvars with bucket $bucket_name"
   echo "bucket_name=$bucket_name" > $stack_path/oss.auto.tfvars
   log "info" "<uploadArchiveOCI><update_oss_auto_tfvars><exit>"
}

