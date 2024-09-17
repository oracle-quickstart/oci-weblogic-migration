#!/usr/bin/env bash

# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

set -o pipefail

scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.."; pwd)
LOG_FILE='upload_to_oci_archive.log'
INVENTORY_FILE='wlsdomain.json'
OCI_COMPARTMENT_ID=${4:-ocid1.compartment.oc1..aaaaaaaaedp6oipcdpkx3md6c3ecdfltlq7wl7lb5q2oj4756edqk2lvj5zq}

[ "$user_functions_loaded" ] || source ./shared.sh

function pre-reqs(){
    log "info" "Verifying OCI cli."
    if ! oci iam region list >> "$LOG_FILE" 2>&1; then
        log "error" "Fail to verify OCI cli is configured. For more information visit: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
        log "error" "exiting..."
        return 1
    fi
    local bucket_name=$1
    local compartment_id=$2
    log "info" "Verifying OCI Bucket."
    if ! oci os bucket get --bucket-name "$bucket_name" >> "$LOG_FILE" 2>&1; then
        log "error" "bucket or autorization does not exist. Attempting to create bucket..."
        if ! oci os bucket create --name $bucket_name --compartment-id $OCI_COMPARTMENT_ID >> "$LOG_FILE" 2>&1; then
            log "error" "Failed to create bucket. Check OCI credentials. Exiting..."
            return 1
        fi
        log "info" "Bucket created. "
    fi
    log "info" "Bucket exists. Continuing..."
}

log "info" "Starting tool to upload WLS Archives to Oracle Cloud Infrastructure Object Storage"
OSS_NAMESPACE=${1:-}
log "debug" "Namespace: $OSS_NAMESPACE"
BUCKET_NAME=${2:-$(jq --raw-output -c '.topology.Name' $INVENTORY_FILE)}
log "debug" "Bucket: $BUCKET_NAME"
repo_archive_path=${3:-$(pwd)}
domain_name=$(jq --raw-output -c '.topology.Name' $INVENTORY_FILE)
log "debug" "Domain Name: $domain_name"
REPOSITORY_PATH=$repo_archive_path/$domain_name
log "info" "$REPOSITORY_PATH found. "
pre-reqs $BUCKET_NAME $OCI_COMPARTMENT_ID
log "info" "pre-requisites.          PASSED "
for machine in $(jq --raw-output -c '.resources.Machines|keys[]' $INVENTORY_FILE); do
    # do stuff with pretty-printed, multi-line "$i"
    log "info" "uploading wls archive files to bucket $BUCKET_NAME"
    #TODO: JOI - Revisig shopt to avoid ls output
    #shopt -s nullglob  # expand globs to nothing if no match
    for f in $REPOSITORY_PATH/$machine*;
    do
        [[ -e "$f" ]] || break
        log "info" "uploading archive $f"
        oci os object put --namespace "$OSS_NAMESPACE" --bucket-name "$BUCKET_NAME" --file "$f" --force >> "$LOG_FILE";
    done
done