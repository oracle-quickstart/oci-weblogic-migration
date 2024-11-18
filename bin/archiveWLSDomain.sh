#!/usr/bin/env bash
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : install_dependencies.sh
# Description          : Install all required dependencies needed to run OCI Weblogic Migration Tool
# Dependencies         : $DEPS_WDT_HOME set in shared.sh
# Input
#  $1  - Weblogic Inventory File  (JSON) - INVENTORY_FILE
#  $2  - Folder name to store Archives locally - REPOSITORY_FOLDER
#  $3  - Path to create REPOSITORY_FOLDER -  REPO_ARCHIVE_PATH
#############################################################################################################################


scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.." || exit; pwd)
LOG_FILE_NAME='owm_upload_archive_to_oci.log'


[ "$user_functions_loaded" ] || source ./shared.sh
#WLS_HOST=""


function create_repository(){
    local repo_path=$1
    mkdir -p "$repo_path" > /dev/null
}

function check_space_archives(){
  if [[ "z$multi_tar" == "z" ]]; then
    run_ssh_command "du -sh --total" "$path_to_wls_dir"
  else
    run_ssh_command "du -sh --total" "${path_to_wls_dir[@]}"
  fi
}

#Creates a remote tar and then bring it home via scp
function remote_taring(){
      local file_name=$1
      local repo=$2
      local path_to_wls_dir=$3
      local multi_tar=$4
      #TODO: Sept 17th  exclude servers/managedserver2/data/store/diagnostics/
      #--exclude='servers/*/data/store/diagnostics/* --exclude='log' '
      #local FILTERS="--exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='*.log*'"
      local FILTERS=""
      if [[ "z$multi_tar" == "z" ]]; then
          log "info" "Connecting to host: $WLS_HOST and archiving $path_to_wls_dir"
          TAR_COMMAND="tar czf $wdt_home/out/$file_name $FILTERS $path_to_wls_dir"
          if [[ $DRY_RUN -eq 1 ]]; then
            echo "Command to run on each host: "
            echo "$TAR_COMMAND"
          else
            run_piped_ssh_command "$repo/$file_name.ctrl" "$TAR_COMMAND"
            secure_copy "$wdt_home/out/$file_name" "$repo/"
          fi
      else
          log "info" "Archiving Custom Directories"
          shift;shift;shift;shift;            # Shift all arguments to the left
          local path_to_wls_dir=("$@")    # Rebuild the array with rest of arguments
          log "debug" "${path_to_wls_dir[@]}"
          TAR_COMMAND="tar czf $wdt_home/out/$file_name $FILTERS ${path_to_wls_dir[*]}"
          if [[ $DRY_RUN -eq 1 ]]; then
              echo "Command to run on each host: "
              echo "$TAR_COMMAND"
          else
              run_piped_ssh_command "$repo/$file_name.ctrl" "tar czf $wdt_home/out/$file_name" "$FILTERS" "${path_to_wls_dir[@]}"
              secure_copy "$wdt_home/out/$file_name" "$repo/"
          fi

      fi
      log "info" "Archiving Complete"
}
###
## Compresses over ssh using stream output
##
#function remote_compress(){
#    local file_name=$1
#    local repo=$2
#    local path_to_wls_dir=$3
#    local multi_tar=$4
#    local FILTERS="--exclude='.pid' --exclude='.state' --exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='*.log*'"
#    if [[ "z$multi_tar" == "z" ]]; then
#        log "info" "Connecting to host: $WLS_HOST and archiving $path_to_wls_dir"
##        ssh $WLS_HOST "tar czf - $FILTERS $path_to_wls_dir" > $REPO_ARCHIVE_PATH/$file_name
#        run_piped_ssh_command $repo/$file_name "tar czf - $FILTERS $path_to_wls_dir"
#    else
#        log "info" "Archiving Custom Directories"
#        shift;shift;shift;shift;            # Shift all arguments to the left
#        local path_to_wls_dir=("$@")    # Rebuild the array with rest of arguments
#        log "debug" "${path_to_wls_dir[@]}"
#        # echo "$WLS_HOST \"tar czf - $FILTERS ${path_to_wls_dir[@]} \" > $REPO_ARCHIVE_PATH/$file_name"
##        ssh $WLS_HOST "tar czf - $FILTERS" "${path_to_wls_dir[@]}" > "$REPO_ARCHIVE_PATH/$file_name"
#        run_piped_ssh_command "$repo/$file_name" "tar czf - $FILTERS" "${path_to_wls_dir[@]}"
#    fi
#    log "info" "Archiving Complete"
#}

function process_custom_dirs(){
   local dirs_list=$1 #this should be a list of files.
   remote_compress $dirs_list "$machinename-$domain_name-custom_dirs.tar.gz"
}


# ssh $host "tar -cz - --exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*' $middleware_path" > $REPO_ARCHIVE_PATH/$machinename-$domain_name-weblogic_home.tar.gz
# ssh $host "tar -cz - --exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*' $jdk_path" > $REPO_ARCHIVE_PATH/$machinename-$domain_name-java_home.tar.gz
# ssh $host "tar -cz - --exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*' $domain_path" > $REPO_ARCHIVE_PATH/$machinename-$domain_name-domain_home.tar.gz
# ssh $host "tar -cz - --exclude='logs' --exclude='.pid' --exclude='.state' --exclude='oracle-dfw-*/sampling/jvm_threads*' --exclude='core' --exclude='*/tmp/*' --exclude='log' --exclude='*.log*' $custom_dirs" > $REPO_ARCHIVE_PATH/$machinename-$domain_name-custom_dirs.tar.gz

archiveWLSDomain(){
    local REPO="$toolHome/out/$REPOSITORY_FOLDER"
    domain_name=$(jq --raw-output -c '.topology.Name' $INVENTORY_FILE)
    middleware_path=$(jq --raw-output -c '.topology.OraclePath' $INVENTORY_FILE)
    domain_path=$(jq --raw-output -c '.topology.DomainPath' $INVENTORY_FILE)
    create_repository "$REPO"
    custom_dirs_to_copy=()
    for machinename in $(jq --raw-output -c '.resources.Machines|keys[]' $INVENTORY_FILE); do
        # do stuff with pretty-printed, multi-line "$i"
        host=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].DETAILS.Hostname' $INVENTORY_FILE)
    #    WLS_HOST="-i $PRIV_SSH_KEY_PATH domain@$host $JUMP_HOST_OPTION"
        ssh_admin_server_host=$host
        jdk_path=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].JavaPath' $INVENTORY_FILE)
        custom_dir=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].ExtraOSPaths|to_entries| .[] |.value' $INVENTORY_FILE )
        # echo "${custom_dirs_to_copy[@]}"
        remote_taring "$machinename-$domain_name-java_home.tar.gz" $REPO $jdk_path
        remote_taring "$machinename-$domain_name-domain_home.tar.gz" $REPO $domain_path
        remote_taring "$machinename-$domain_name-weblogic_home.tar.gz" $REPO $middleware_path
        # index=0
        if [[ "z$custom_dir" != "z" ]]; then
            for dir_entry in $custom_dir; do
                #remote_compress "$machinename-$domain_name-custom_dirs_$index.tar.gz" $REPO_ARCHIVE_PATH $dir_entry
                custom_dirs_to_copy+=("$dir_entry")
            done
            # echo $custom_dirs_to_copy
            remote_taring "$machinename-$domain_name-custom_dirs.tar.gz" $REPO "-" "y" "${custom_dirs_to_copy[@]}"
        fi
    done
}


############################################################
# help                                                     #
############################################################
help()
{
  echo "Archive a Weblogic Migration required Directory"
  echo
  echo "Arguments: archiveWLSDomain.sh -i|--inventory-file <stack_name> -r|--repository <folder_Store_Archives>  optional: -d|--dry-run "
  echo "options:"
  echo "-i, --inventory     Path to Inventory File (JSON Format). Relavite or Absolute Path"
  echo "-r, --repository    Folder name under $toolHome/out directory"
  echo "-d, --dry-run    Show archiving commands to run manually"
  echo
}

if [ $# -eq 0 ]; then
    help
    exit 1
fi

log "info" "<archiveWLSDomain><init> parsing flags"
while [ $# -ne 0 ]
do
    case $1 in
        -h|--help)
            help
            exit 1
            ;;
        -r|--repository)
            REPOSITORY_FOLDER="$2"
	          shift
            ;;
        -i|--inventory-file)
            INVENTORY_FILE="$2"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=1
            ;;
        *)
            help
            exit 1
            ;;
    esac
    shift
done

# validate the input parameters
validate()
{
  log "info" "<archiveWLSDomain><validate><entry>"
  if [ -z "${REPOSITORY_FOLDER}" ]; then
    echo "Repository Folder Missing. Resulting compressed Archive files will be stored under $toolHome/out"
  fi

  if [ -z "${INVENTORY_FILE}" ]; then
     echo "Inventory file missing. exiting.."
     help
     exit 1
  elif [ "z${INVENTORY_FILE}" == "z-i" ] || [ "z${INVENTORY_FILE}" == "z--inventory" ] || [ "z${INVENTORY_FILE}" == "znone" ]; then
       echo "Inventory file missing. exiting.."
       help
       exit 1
  fi


#  echo "$REPOSITORY_FOLDER"
#  echo "$INVENTORY_FILE"
  log "info" "<archiveWLSDomain><validate><exit> $REPOSITORY_FOLDER $INVENTORY_FILE"
}

#Run validation for the input parameters
validate

archiveWLSDomain 
#deploy_to_orm
exit 0