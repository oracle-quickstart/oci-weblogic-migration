#!/usr/bin/env bash
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : install_dependencies.sh
# Description          : Install all required dependencies needed to run OCI Weblogic Migration Tool
# Dependencies         : $DEPS_WDT_HOME set in common.sh
#############################################################################################################################


scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.." || exit; pwd)
LOG_FILE_NAME='owm_upload_archive_to_oci.log'


[ "$user_functions_loaded" ] || source ./shared.sh

WLS_HOST=""


function pre_reqs(){
    local domain=$1
    mkdir -p "$REPO_ARCHIVE_PATH/$domain" > /dev/null
}

function remote_compress(){
    local file_name=$1
    local REPO_ARCHIVE_PATH=$2
    local path_to_wls_dir=$3
    local multi_tar=$4
    local FILTERS="--exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*'"
    if [[ "z$multi_tar" == "z" ]]; then
        log "info" "Connecting to host: $WLS_HOST and archiving $path_to_wls_dir"
        ssh $WLS_HOST "tar czf - $FILTERS $path_to_wls_dir" > $REPO_ARCHIVE_PATH/$file_name
    else
        log "info" "Archiving Custom Directories"
        shift;shift;shift;shift;            # Shift all arguments to the left
        local path_to_wls_dir=("$@")    # Rebuild the array with rest of arguments
        log "debug" "${path_to_wls_dir[@]}"
        # echo "$WLS_HOST \"tar czf - $FILTERS ${path_to_wls_dir[@]} \" > $REPO_ARCHIVE_PATH/$file_name"
        ssh $WLS_HOST "tar czf - $FILTERS" "${path_to_wls_dir[@]}" > "$REPO_ARCHIVE_PATH/$file_name"
    fi
    log "info" "Archiving Complete"
}

function process_custom_dirs(){
   local dirs_list=$1 #this should be a list of files.
   remote_compress $dirs_list "$machinename-$domain_name-custom_dirs.tar.gz"
}


# ssh $host "tar -cz - --exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*' $middleware_path" > $REPO_ARCHIVE_PATH/$machinename-$domain_name-weblogic_home.tar.gz
# ssh $host "tar -cz - --exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*' $jdk_path" > $REPO_ARCHIVE_PATH/$machinename-$domain_name-java_home.tar.gz
# ssh $host "tar -cz - --exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*' $domain_path" > $REPO_ARCHIVE_PATH/$machinename-$domain_name-domain_home.tar.gz
# ssh $host "tar -cz - --exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*' $custom_dirs" > $REPO_ARCHIVE_PATH/$machinename-$domain_name-custom_dirs.tar.gz


domain_name=$(jq --raw-output -c '.topology.Name' $INVENTORY_FILE)
middleware_path=$(jq --raw-output -c '.topology.OraclePath' $INVENTORY_FILE)
domain_path=$(jq --raw-output -c '.topology.DomainPath' $INVENTORY_FILE)
pre_reqs $domain_name
REPO_ARCHIVE_PATH=$REPO_ARCHIVE_PATH/$domain_name
custom_dirs_to_copy=()
for row in $(jq --raw-output -c '.resources.Machines|keys[]' $INVENTORY_FILE); do
    # do stuff with pretty-printed, multi-line "$i"
    machinename=$row
    host=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].DETAILS.Hostname' $INVENTORY_FILE)
    WLS_HOST="-i $PRIV_SSH_KEY_PATH domain@$host $JUMP_HOST_OPTION"
    jdk_path=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].JavaPath' $INVENTORY_FILE)
    custom_dir=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].ExtraOSPaths|to_entries| .[] |.value' $INVENTORY_FILE )
    # echo "${custom_dirs_to_copy[@]}"
    remote_compress "$machinename-$domain_name-java_home.tar.gz" $REPO_ARCHIVE_PATH $jdk_path
    remote_compress "$machinename-$domain_name-domain_home.tar.gz" $REPO_ARCHIVE_PATH $domain_path
    remote_compress "$machinename-$domain_name-weblogic_home.tar.gz" $REPO_ARCHIVE_PATH $middleware_path
    # index=0
    if [[ "z$custom_dir" != "z" ]]; then
        for dir_entry in $custom_dir; do
            #remote_compress "$machinename-$domain_name-custom_dirs_$index.tar.gz" $REPO_ARCHIVE_PATH $dir_entry
            custom_dirs_to_copy+=("$dir_entry")
        done
        # echo $custom_dirs_to_copy
        remote_compress "$machinename-$domain_name-custom_dirs.tar.gz" $REPO_ARCHIVE_PATH "-" "y" "${custom_dirs_to_copy[@]}"
    fi
done
