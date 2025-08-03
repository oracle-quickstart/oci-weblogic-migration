#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.${user}.com/licenses/upl
# shellcheck disable=SC1091 # Ignore unresolved file path present on base images

set -o pipefail

#Required vars
# ${GROUP_ID}
# ${USER_ID}
# SSH_PUB_KEY
# $user
# $group

FAILURE='false'

GROUP_ID=${GROUP_ID}
USER_UID=${USER_ID}
SSH_PUB_KEY="${SSH_PUB_KEY}"

fileName=$(basename $BASH_SOURCE)

function get_logs_dir {
  response_code=$(curl  --write-out '%%{http_code}' --silent --output /dev/null -H "Authorization:Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/logs_dir)
  if [[ "$response_code" -eq 200 ]] ; then
     logs_dir=$(curl -H "Authorization:Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/logs_dir)
     echo $logs_dir
  else
     logs_dir=$(curl -L http://169.254.169.254/opc/v1/instance/metadata/logs_dir)
     echo $logs_dir
  fi
}

logs_dir=`get_logs_dir`
mkdir -p $${logs_dir}
log_file="$${logs_dir}/os-users.log"
error_log_file="$${logs_dir}/cloud-init-errors.log"


function log(){
    while IFS= read -r line; do
            DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
            echo "<$DATE>  $line"
    done
}

#function log(){
#    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
#    level=$1
#    message=$2
#    echo "$timestamp" ["$${level^^}"] "$message"
#}

function change_gid() {  
    new_gid=$1
    used_by=$2
    echo "<cloud-init-wls-user><change_gid><entry> $new_gid and $used_by" | log >> $log_file
    old_gid=$(grep ^"$used_by": /etc/group | cut -d ":" -f 3)
    exit_code=$?
    echo $old_gid | log >> $log_file
    
    echo "<cloudinit-wls-user><change_gid>Running groupmod -g $new_gid $used_by" | log >> $log_file
    
    output=$(groupmod -g "$new_gid" "$used_by")
    exit_code=$?
    echo $output | log >> $log_file
    if [ $exit_code -ne 0 ]; then
        echo  "<cloud-init-wls-user><change_gid><ERROR> Could not change GID for group $used_by" | log | tee -a $log_file >> $error_log_file
        echo "$output" | log >> $error_log_file
        return 1
    fi

    echo "<cloudinit-wls-user><change_gid>Changing ownership of all files owned by group $used_by to new GID $new_gid" | log >> $log_file
    echo "<cloudinit-wls-user><change_gid>Running find / -path /sys -prune -o -path /proc -prune -o -group $old_gid -exec chgrp -h $used_by {} \;" | log >> $log_file

    # the following convoluted and (apparently) superflous line of code is used to mitigate false
    # failures caused by some temporary files found by find that are deleted before find stats them
    # GitLab issue #12
    if ! find / -path /sys -prune -o -path /proc -prune -o -group "$old_gid" -print0 |  xargs -0 -i bash -c "if test -e {}; then chgrp -h $used_by {}; fi" ; then
        echo "<cloudinit-wls-user><change_gid><ERROR>Could not change ownership of all files owned by group $used_by to new GID $new_gid" | log | tee -a $log_file >> $error_log_file
        return 1
    fi
    return 0
}

function shift_gid() {
    gid=$1
    used_by=$(grep "$gid" /etc/group | cut -d ":" -f 1)
    echo "<cloudinit-wls-user><shift_gid><entry>GID $gid and $used_by" | log >> $log_file
    new_gid=$gid
    available=0
    while [[ $available -eq 0 ]]; do
        new_gid=$((new_gid+1));
        if ! grep -q $new_gid /etc/group; then
            echo "<cloudinit-wls-user><shift_gid>GID $new_gid is available - changing GID for group $used_by" | log >> $log_file
            available=1
        fi
    done
    change_gid "$new_gid" "$used_by"
}

function change_group_id() {
    local method="change_group_id"
    group_name=$1
    group_gid=$2
    echo "<cloudinit-wls-user><$method><entry>Checking if GID $group_gid <$group_name> is used by a different group" | log >> $log_file
    if grep -q "$group_gid" /etc/group; then
        used_by=$(grep "$group_gid" /etc/group | cut -d ":" -f 1)
        echo "<cloudinit-wls-user><$method><WARN>GID $group_gid is already used by $used_by - shifting GIDs" | log | tee -a $log_file >> $error_log_file
        if ! shift_gid "$group_gid"; then
            echo "<cloudinit-wls-user><$method><error> Could not shift GID of group $used_by" | log | tee -a $log_file >> $error_log_file
            echo "<cloudinit-wls-user><$method><error>Failed changing $group_name GID to $group_gid" | log | tee -a $log_file >> $error_log_file
            return 1
        else
            echo "<cloudinit-wls-user><$method>Successfully shifted $used_by GID" | log >> $log_file
            echo "<cloudinit-wls-user><$method>Changing $group_name GID to $group_gid" | log >> $log_file
        fi
    else
        echo "<cloudinit-wls-user><$method>GID $group_gid is available - changing $group_name GID to $group_gid" | log >> $log_file
    fi
    if ! change_gid "$group_gid" "$group_name"; then
        echo "<cloudinit-wls-user><$method><ERROR>Failure encountered when trying to change $group_name GID to $group_gid" | log | tee -a $log_file >> $error_log_file
        return 1
    fi
    echo "<cloudinit-wls-user><$method><exit>" | log >> $log_file
    return 0
}

function create_group() {
    local method="create_group"
    group_name=$1
    group_gid=$2
    echo "<cloudinit-wls-user><$method><entry>Checking if GID $group_gid and $group_name is used by a different group" | log >> $log_file
    if grep -q "$group_gid" /etc/group; then
        used_by=$(grep "$group_gid" /etc/group | cut -d ":" -f 1)
        echo "<cloudinit-wls-user><$method><WARN>GID $group_gid is already used by $used_by - shifting GIDs" | log | tee -a $log_file >> $error_log_file
        if ! shift_gid "$group_gid"; then
            echo "<cloudinit-wls-user><$method>Could not shift GID of group $used_by"  | log | tee -a $log_file >> $error_log_file
            echo "<cloudinit-wls-user><$method>Failed creating group $group_name with GID $group_gid" | log | tee -a $log_file >> $error_log_file
            return 1
        else
            echo "<cloudinit-wls-user><$method>Successfully shifted $used_by GID" | log >> $log_file
        fi
    else
        echo "<cloudinit-wls-user><$method>GID $group_gid not used by another group" | log >> $log_file
    fi
    echo "<cloudinit-wls-user><$method>Creating $group_name with GID $group_gid" | log >> $log_file
    echo "<cloudinit-wls-user><$method>Running groupadd $group_name -g $group_gid" | log >> $log_file
    if ! groupadd "$group_name" -g "$group_gid" ; then
        echo "<cloudinit-wls-user><$method><ERROR>Could not create group $group_name with GID $group_gid" | log | tee -a $log_file >> $error_log_file
        return 1
    fi
    echo "<cloudinit-wls-user><$method><exit>" | log >> $log_file
    return 0
}

function change_uid() {
    local method="change_uid"
    new_uid=$1
    used_by=$2
    old_uid=$(grep ^"$used_by": /etc/passwd | cut -d ":" -f 3)
    echo "<cloudinit-wls-user><$method><entry>Running usermod -u $new_uid $used_by" | log >> $log_file

    if ! usermod -u "$new_uid" "$used_by" ; then
        echo "<cloudinit-wls-user><$method><ERROR>Could not change UID for user $used_by" | log | tee -a $log_file >> $error_log_file
        return 1
    fi
    echo "<cloudinit-wls-user><$method>Changing ownership of all files owned by user $used_by to new UID $new_uid" | log >> $log_file
    echo "<cloudinit-wls-user><$method>Running find / -path /sys -prune -o -path /proc -prune -o -user $old_uid -exec chown -h $used_by {} \;" | log >> $log_file
    # the following convoluted and (apparently) superflous line of code is used to mitigate false
    # failures caused by some temporary files found by find that are deleted before find stats them
    # GitLab issue #12
    if ! find / -path /sys -prune -o -path /proc -prune -o -user "$old_uid" -print0 | xargs -0 -i bash -c "if test -e {}; then chown -h $used_by {}; fi" ; then
        echo "<cloudinit-wls-user><$method><ERROR>Could not change ownership of all files owned by user $used_by to new UID $new_uid" | log | tee -a $log_file >> $error_log_file
        return 1
    fi
    echo "<cloudinit-wls-user><$method><exit>" | log >> $log_file
    return 0
}

function shift_uid() {
    local method="shift_uid"
    uid=$1
    used_by=$(id -u "$user_id" -n)
    new_uid=$uid
    available=0
    echo "<cloudinit-wls-user><$method><entry>" | log >> $log_file
    while [[ $available -eq 0 ]]; do
        new_uid=$((new_uid+1));
        if ! id -u "$new_uid" -n > /dev/null 2>&1; then
            echo "<cloudinit-wls-user><$method>UID $new_uid is available - changing UID for user $used_by" | log >> $log_file
            available=1
        fi
    done
    echo "<cloudinit-wls-user><$method><exit>" | log >> $log_file
    change_uid "$new_uid" "$used_by"
}

function change_user_id() {
    local method="change_user_id"
    user_name=$1
    user_id=$2
    echo "<cloudinit-wls-user><$method><entry>Checking if UID $user_id is used by another user" | log >> $log_file
    if id "$user_id" > /dev/null 2>&1; then
        used_by=$(id -u "$user_id" -n)
        echo "<cloudinit-wls-user><$method><WARN>UID $user_id used by user $used_by - shifting UIDs" | log | tee -a $log_file >> $error_log_file
        if ! shift_uid "$user_id"; then
            echo "<cloudinit-wls-user><$method><ERROR>Failures encountered when trying to shift UID" | log | tee -a $log_file >> $error_log_file
            return 1
        else
            echo "<cloudinit-wls-user><$method>Successfully shifted user $used_by UID" | log >> $log_file
            echo "<cloudinit-wls-user><$method>Changing $user_name UID to $user_id" | log >> $log_file
        fi
    else
        echo "<cloudinit-wls-user><$method>UID $user_id not used by any other user" | log >> $log_file
    fi
    echo "<cloudinit-wls-user><$method>Changing user $user_name UID to $user_id" | log >> $log_file
    if ! change_uid "$user_id" "$user_name"; then
        echo "<cloudinit-wls-user><$method><ERROR>Encountered failures when trying to change user $user_name UID to $user_id" | log | tee -a $log_file >> $error_log_file
        return 1
    fi
    echo "<cloudinit-wls-user><$method>Successfully changed user $user_name UID to $user_id" | log >> $log_file
    return 0
}

function create_user() {
    local method="create_user"
    user_name=$1
    user_id=$2
    echo "<cloudinit-wls-user><$method>Checking if UID $user_id is used by a another user" | log >> $log_file
    if id "$user_id" > /dev/null 2>&1; then
        used_by=$(id -u "$user_id" -n)
        echo "<cloudinit-wls-user><$method><WARN>UID $user_id is already used by $used_by - shifting UIDs" | log | tee -a $log_file >> $error_log_file
        if ! shift_uid "$user_id"; then
            echo "<cloudinit-wls-user><$method><ERROR>Could not shift UID of user $used_by" | log | tee -a $log_file >> $error_log_file
            return 1
        else
            echo "<cloudinit-wls-user><$method>Successfully shifted $used_by UID" | log >> $log_file
        fi
    else
        echo "<cloudinit-wls-user><$method>GID $user_id not used by another user" | log >> $log_file
    fi
    echo "<cloudinit-wls-user><$method>Creating $user_name with UID $user_id" | log >> $log_file
    echo "<cloudinit-wls-user><$method>Running useradd -u $user_id $user_name" | log >> $log_file
    if ! useradd -u "$user_id" "$user_name" ; then
        echo "<cloudinit-wls-user><$method><ERROR>Could not create user $user_name with UID $user_id" | log | tee -a $log_file >> $error_log_file
        return 1
    fi
    echo "<cloudinit-wls-user><$method>Created user $user_name with UID $user_id" | log >> $log_file
    return 0
}

function myexit() {
    local method="myexit"
    if [[ $FAILURE == 'true' ]]; then
        echo "<cloudinit-wls-user><$method><ERROR>Error restoring wls archives during startup" | log | tee -a $log_file >> $error_log_file 1>&2;
        exit 1
    else
        echo "<cloudinit-wls-user><$method><exit>User setup SUCCESS" | log >> $log_file 1>&2;
        exit 0
    fi
}

#INIT PROGRAM

if [[ -z "$GROUP_ID" ]] || [[ "z$GROUP_ID" == "z" ]]; then
    echo "<cloudinit-wls-user><init>GROUP_ID has invalid value: [$GROUP_ID]" | log | tee -a $log_file >> $error_log_file
    FAILURE='true'
    myexit
fi

if [[ -z "$USER_UID" ]] || [[ "z$USER_UID" == "z" ]]; then
    echo "<cloudinit-wls-user><init>USER_UID has invalid value: [$USER_UID]" | log | tee -a $log_file >> $error_log_file
    FAILURE='true'
    myexit
fi


echo "<cloudinit-wls-user><init>Verifying ${group} group exists and has proper GID" | log >> $log_file
if grep -q ${group} /etc/group; then
    echo "<cloudinit-wls-user><init>${group} group exists - checking GID" | log >> $log_file
    if grep ${group} /etc/group | grep -q "$GROUP_ID"; then
        echo "<cloudinit-wls-user><init>${group} has proper GID" | log >> $log_file
    else
        echo "<cloudinit-wls-user><init>${group} exists, but has different GID than on-prem - changing GID" | log >> $log_file
        if ! change_group_id "${group}" "$GROUP_ID"; then
            FAILURE='true'
            myexit
        fi
    fi
else
    echo "<cloudinit-wls-user><init>${group} does not exist - creating with GID $GROUP_ID" | log >> $log_file
    if ! create_group  "${group}" "$GROUP_ID"; then
        FAILURE='true'
        myexit
    fi
fi

is_${user}_valid="true"
echo "<cloudinit-wls-user><init>Verifying ${user} user exists and has proper UID" | log >> $log_file
if grep -q ^${user}: /etc/passwd; then
    echo "<cloudinit-wls-user><init>${user} user exists - checking UID" | log >> $log_file
    is_${user}_uid=$(grep ^${user}: /etc/passwd | cut -d ":" -f 3)
    if [[ "$is_${user}_uid" == "$USER_UID" ]]; then
        echo "<cloudinit-wls-user><init>${user} user has proper UID ($USER_UID)" | log >> $log_file
    else
        echo "<cloudinit-wls-user><init><WARN>${user} user has different UID - changing" | log >> $log_file
        if ! change_user_id "${user}" "$USER_UID"; then
            FAILURE='true'
            is_${user}_valid="false"
            myexit
        fi
    fi
else
    echo "<cloudinit-wls-user><init>User ${user} does not exist - creating with UID $USER_UID" | log >> $log_file
    if ! create_user "${user}" "$USER_UID"; then
        FAILURE='true'
        is_${user}_valid="false"
        myexit
    fi
fi

if [[ "$is_${user}_valid" == "true" ]]; then
    echo "<cloudinit-wls-user><init>Making sure user ${user} has the proper groups associated" | log >> $log_file
    echo "<cloudinit-wls-user><init>Running usermod ${user} -g ${group} ${user}" | log >> $log_file
    if ! usermod -g ${group} ${user} ; then
        FAILURE='true'
        echo "<cloudinit-wls-user><init>Failed to associate proper groups to ${user} user" | log | tee -a $log_file >> $error_log_file
        myexit
    else
        echo "<cloudinit-wls-user><init>Proper groups associated to user ${user}" | log >> $log_file
    fi
fi

echo "<cloudinit-wls-user><init>Creating /home/${user}/.ssh directory" | log >> $log_file
if ! mkdir -p /home/${user}/.ssh ; then
    echo "<cloudinit-wls-user><init>Failed creating /home/${user}/.ssh directory" | log | tee -a $log_file >> $error_log_file
    FAILURE='true'
    myexit
else
    echo "<cloudinit-wls-user><init>Adding ssh public key to '${user}' authorized hosts" | log >> $log_file
    echo "$SSH_PUB_KEY" >> /home/${user}/.ssh/authorized_keys
fi

echo "<cloudinit-wls-user><init>Setting .ssh directory and contents correct permissions"  | log >> $log_file
chown -R ${user}:${group} /home/${user}/.ssh
chmod 700 /home/${user}/.ssh
chmod 600 /home/${user}/.ssh/authorized_keys


# Pre-create provisioning log as oracle user so it is owned by oracle user.
# This is to avoid race-condition if logging happens from a script running as root user first then
# provisioning log is created and owned by root user. So we pre-create it before any logging happens
# to provisioning log file.
output=$(touch "$${logs_dir}/provisioning.log")
exit_code=$?
echo $output | log >> $log_file
if [ $exit_code -ne 0 ]; then
    echo  "<cloudinit-wls-user><init><ERROR> Failed to create provisioning.log" | log | tee -a $log_file >> $error_log_file
    echo "$output" | log >> $error_log_file
    exit 1
else
  # grant write permission to the opc user for the log file. This is required for cloning operation.
  chown ${user}: "$${logs_dir}/provisioning.log"
  #sudo -E -u ${user} chmod 777 "$${logs_dir}"
  sudo -E -u ${user} -E chmod a+w "$${logs_dir}/provisioning.log"
  echo  "<cloudinit-wls-user><init> Permissions set to provisioning.log" | log >> $log_file
fi
echo  "<cloudinit-wls-user><init><exit>" | log >> $log_file