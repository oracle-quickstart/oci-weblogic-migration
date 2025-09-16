#!/usr/bin/env bash
# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

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
OWM_PATH="$toolHome"
logs_dir="$toolHome/logs"
log_file="${logs_dir}/owm_archive_domain.log"
LOG_FILE_NAME="owm_archive_domain.log"

#function log() {
#    while IFS= read -r line; do
#        DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
#        echo "<$DATE>  $line"
#    done
#}



[ "$user_functions_loaded" ] || source ./shared.sh
echo "functions loaded [ "$user_functions_loaded" ]" | log >> "$log_file" ;
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
      echo "<archiveWLSDomain><remote_taring><entry> args : $*" | log >> "$log_file" ;
      local file_name=$1  #machine_name_type.tgz
      local repo=$2   #$toolsHome/out
      local path_to_wls_dir=$3  #/opt/domains/mydomain
      local multi_tar=$4   # any value to indicate custom has multi directories.
      local FILTERS_OS="--exclude='.pid' --exclude='.state' --exclude='core' --exclude='diag/ofm/*/*/lck/*.lck'"
      local FILTERS_DIAG="--exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*'"
      local FILTERS_EXTRA="--exclude='*/tmp/*' --exclude='*.log*'"
      local FILTERS="$FILTERS_OS $FILTERS_DIAG $FILTERS_EXTRA"
      # Check if custom directories are to be archived. if flag multi_tar must be set.
      if [[ "z$multi_tar" == "z" ]]; then
          echo "archiving $path_to_wls_dir" | log >> "$log_file" ;
          TAR_COMMAND="tar czf $repo/$file_name $FILTERS $path_to_wls_dir"
          if [[ $DRY_RUN -eq 1 ]]; then
            echo "Command to run on each host: "
            echo "$TAR_COMMAND"
          else
            run_piped_ssh_command "$repo/$file_name.ctrl" "$TAR_COMMAND"
            secure_copy "$repo/$file_name" "$repo/"
            delete_remote_file
          fi
      else
          echo "Archiving Custom Directories" | log >> "$log_file" ;
          shift;shift;shift;shift;            # Shift all arguments to the left
          local path_to_wls_dir=("$@")    # Rebuild the array with rest of arguments
          #log "debug" "${path_to_wls_dir[@]}"
          TAR_COMMAND="tar czf $repo/$file_name $FILTERS ${path_to_wls_dir[*]}"
          if [[ $DRY_RUN -eq 1 ]]; then
              echo "Command to run on each host: "
              echo "$TAR_COMMAND"
          else
              run_piped_ssh_command "$repo/$file_name.ctrl" "tar czf $repo/$file_name" "$FILTERS" "${path_to_wls_dir[@]}"
              secure_copy "$repo/$file_name" "$repo/"
          fi

      fi
      echo "<archiveWLSDomain><remote_taring><exit>" | log >> "$log_file" ;
}


function process_custom_dirs(){
   local dirs_list=$1 #this should be a list of files.
   remote_compress $dirs_list "$machinename-$domain_name-custom_dirs.tar.gz"
}


function archiveWLSDomain(){
    echo "<archiveWLSDomain><archiveWLSDomain><entry>" | log >> "$log_file" ;
    local REPO="$toolHome/out/$REPOSITORY_FOLDER"
    domain_name=$(jq --raw-output -c '.topology.Name' $INVENTORY_FILE)
    middleware_path=$(jq --raw-output -c '.topology.OraclePath' $INVENTORY_FILE)
    domain_path=$(jq --raw-output -c '.topology.DomainPath' $INVENTORY_FILE)
    create_repository "$REPO"
    custom_dirs_to_copy=()
    # Even if it is running from AdminServer. It ssh locally to tar folders"
    for machinename in $(jq --raw-output -c '.resources.Machines|keys[]' $INVENTORY_FILE); do
        # do stuff with pretty-printed, multi-line "$i"
        host=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].DETAILS.Hostname' $INVENTORY_FILE)
    #    WLS_HOST="-i $PRIV_SSH_KEY_PATH domain@$host $JUMP_HOST_OPTION"
        ssh_admin_server_host=$host
        jdk_path=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].JavaPath' $INVENTORY_FILE)
        custom_dir=$(jq --arg m "$machinename" --raw-output -c '.resources.Machines[$m].ExtraOSPaths|to_entries| .[] |.value' $INVENTORY_FILE )
        echo "Machine ${host} : list of dirs jdk_path=$jdk_path , domain_path=$domain_path  , custom: ${custom_dirs_to_copy[@]}" | log >> "$log_file" ;
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
    echo "<archiveWLSDomain><archiveWLSDomain><exit>" | log >> "$log_file" ;
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
        -t|--remote)
            OWM_PATH="$wdt_home"
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
  echo "<archiveWLSDomain><validate><entry>" | log >> "$log_file" ;
  if [ -z "${REPOSITORY_FOLDER}" ]; then
    echo "Repository Folder Missing. Resulting compressed Archive files will be stored under $toolHome/out" | log >> "$log_file" ;
  fi

  if [ -z "${INVENTORY_FILE}" ]; then
     echo "Inventory file missing. exiting.." | log >> "$log_file" ;
     help
     exit 1
  elif [ "z${INVENTORY_FILE}" == "z-i" ] || [ "z${INVENTORY_FILE}" == "z--inventory" ] || [ "z${INVENTORY_FILE}" == "znone" ]; then
       echo "Inventory file missing. exiting.." | log >> "$log_file" ;
       help
       exit 1
  fi


#  echo "$REPOSITORY_FOLDER"
#  echo "$INVENTORY_FILE"
  echo "<archiveWLSDomain><validate><exit> $REPOSITORY_FOLDER $INVENTORY_FILE" | log >> "$log_file" ;
}

#Run validation for the input parameters
validate

archiveWLSDomain 
#deploy_to_orm
exit 0