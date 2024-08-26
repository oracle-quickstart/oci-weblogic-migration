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

function log(){
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    level=$1
    message=$2
    echo "$timestamp" ["$${level^^}"] "$message"
}

function change_gid() {
    new_gid=$1
    used_by=$2
    old_gid=$(grep ^"$used_by": /etc/group | cut -d ":" -f 3)
    log "info" "Running groupmod -g $new_gid $used_by"

    if ! groupmod -g "$new_gid" "$used_by" ; then
        log "error" "Could not change GID for group $used_by"
        return 1
    fi
    log "info" "Changing ownership of all files owned by group $used_by to new GID $new_gid"
    log "info" "Running find / -path /sys -prune -o -path /proc -prune -o -group $old_gid -exec chgrp -h $used_by {} \;"

    # the following convoluted and (apparently) superflous line of code is used to mitigate false
    # failures caused by some temporary files found by find that are deleted before find stats them
    # GitLab issue #12
    if ! find / -path /sys -prune -o -path /proc -prune -o -group "$old_gid" -print0 |  xargs -0 -i bash -c "if test -e {}; then chgrp -h $used_by {}; fi" ; then
        log "error" "Could not change ownership of all files owned by group $used_by to new GID $new_gid"
        return 1
    fi
    return 0
}

function shift_gid() {
    gid=$1
    used_by=$(grep "$gid" /etc/group | cut -d ":" -f 1)
    new_gid=$gid
    available=0
    while [[ $available -eq 0 ]]; do
        new_gid=$((new_gid+1));
        if ! grep -q $new_gid /etc/group; then
            log "info" "GID $new_gid is available - changing GID for group $used_by"
            available=1
        fi
    done
    change_gid "$new_gid" "$used_by"
}

function change_group_id() {
    group_name=$1
    group_gid=$2
    log "info" "Checking if GID $group_gid is used by a different group"
    if grep -q "$group_gid" /etc/group; then
        used_by=$(grep "$group_gid" /etc/group | cut -d ":" -f 1)
        log "warn" "GID $group_gid is already used by $used_by - shifting GIDs"
        if ! shift_gid "$group_gid"; then
            log "error" "Could not shift GID of group $used_by"
            log "error" "Failed changing $group_name GID to $group_gid"
            return 1
        else
            log "info" "Successfully shifted $used_by GID"
            log "info" "Changing $group_name GID to $group_gid"
        fi
    else
        log "info" "GID $group_gid is available - changing $group_name GID to $group_gid"
    fi
    if ! change_gid "$group_gid" "$group_name"; then
        log "error" "Failure encountered when trying to change $group_name GID to $group_gid"
        return 1
    fi
    return 0
}

function create_group() {
    group_name=$1
    group_gid=$2
    log "info" "Checking if GID $group_gid is used by a different group"
    if grep -q "$group_gid" /etc/group; then
        used_by=$(grep "$group_gid" /etc/group | cut -d ":" -f 1)
        log "warn" "GID $group_gid is already used by $used_by - shifting GIDs"
        if ! shift_gid "$group_gid"; then
            log "error" "Could not shift GID of group $used_by"
            log "error" "Failed creating group $group_name with GID $group_gid"
            return 1
        else
            log "info" "Successfully shifted $used_by GID"
        fi
    else
        log "info" "GID $group_gid not used by another group"
    fi
    log "info" "Creating $group_name with GID $group_gid"
    log "info" "Running groupadd $group_name -g $group_gid"
    if ! groupadd "$group_name" -g "$group_gid" ; then
        log "error" "Could not create group $group_name with GID $group_gid"
        return 1
    fi
    log "info" "Created group $group_name with GID $group_gid"
    return 0
}

function change_uid() {
    new_uid=$1
    used_by=$2
    old_uid=$(grep ^"$used_by": /etc/passwd | cut -d ":" -f 3)
    log "info" "Running usermod -u $new_uid $used_by"

    if ! usermod -u "$new_uid" "$used_by" ; then
        log "error" "Could not change UID for user $used_by"
        return 1
    fi
    log "info" "Changing ownership of all files owned by user $used_by to new UID $new_uid"
    log "info" "Running find / -path /sys -prune -o -path /proc -prune -o -user $old_uid -exec chown -h $used_by {} \;"
    # the following convoluted and (apparently) superflous line of code is used to mitigate false
    # failures caused by some temporary files found by find that are deleted before find stats them
    # GitLab issue #12
    if ! find / -path /sys -prune -o -path /proc -prune -o -user "$old_uid" -print0 | xargs -0 -i bash -c "if test -e {}; then chown -h $used_by {}; fi" ; then
        log "error" "Could not change ownership of all files owned by user $used_by to new UID $new_uid"
        return 1
    fi
    return 0
}

function shift_uid() {
    uid=$1
    used_by=$(id -u "$user_id" -n)
    new_uid=$uid
    available=0
    while [[ $available -eq 0 ]]; do
        new_uid=$((new_uid+1));
        if ! id -u "$new_uid" -n > /dev/null 2>&1; then
            log "info" "UID $new_uid is available - changing UID for user $used_by"
            available=1
        fi
    done
    change_uid "$new_uid" "$used_by"
}

function change_user_id() {
    user_name=$1
    user_id=$2
    log "info" "Checking if UID $user_id is used by another user"
    if id "$user_id" > /dev/null 2>&1; then
        used_by=$(id -u "$user_id" -n)
        log "warn" "UID $user_id used by user $used_by - shifting UIDs"
        if ! shift_uid "$user_id"; then
            log "error" "Failures encountered when trying to shift UID"
            return 1
        else
            log "info" "Successfully shifted user $used_by UID"
            log "info" "Changing $user_name UID to $user_id"
        fi
    else
        log "info" "UID $user_id not used by any other user"
    fi
    log "info" "Changing user $user_name UID to $user_id"
    if ! change_uid "$user_id" "$user_name"; then
        log "error" "Encountered failures when trying to change user $user_name UID to $user_id"
        return 1
    fi
    log "info" "Successfully changed user $user_name UID to $user_id"
    return 0
}

function create_user() {
    user_name=$1
    user_id=$2
    log "info" "Checking if UID $user_id is used by a another user"
    if id "$user_id" > /dev/null 2>&1; then
        used_by=$(id -u "$user_id" -n)
        log "warn" "UID $user_id is already used by $used_by - shifting UIDs"
        if ! shift_uid "$user_id"; then
            log "error" "Could not shift UID of user $used_by"
            return 1
        else
            log "info" "Successfully shifted $used_by UID"
        fi
    else
        log "info" "GID $user_id not used by another user"
    fi
    log "info" "Creating $user_name with UID $user_id"
    log "info" "Running useradd -u $user_id $user_name"
    if ! useradd -u "$user_id" "$user_name" ; then
        log "error" "Could not create user $user_name with UID $user_id"
        return 1
    fi
    log "info" "Created user $user_name with UID $user_id"
    return 0
}

function myexit() {
    if [[ $FAILURE == 'true' ]]; then
        echo "Error restoring wls archives during startup" 1>&2;
        exit 1
    else
        echo "User setup SUCCESS" 1>&2;
        exit 0
    fi
}

#INIT PROGRAM

if [[ -z "$GROUP_ID" ]] || [[ "z$GROUP_ID" == "z" ]]; then
    log "error" "GROUP_ID has invalid value: [$GROUP_ID]"
    FAILURE='true'
    myexit
fi

if [[ -z "$USER_UID" ]] || [[ "z$USER_UID" == "z" ]]; then
    log "error" "USER_UID has invalid value: [$USER_UID]"
    FAILURE='true'
    myexit
fi


log "info" "Verifying ${group} group exists and has proper GID"
if grep -q ${group} /etc/group; then
    log "info" "${group} group exists - checking GID"
    if grep ${group} /etc/group | grep -q "$GROUP_ID"; then
        log "info" "${group} has proper GID"
    else
        log "info" "${group} exists, but has different GID than on-prem - changing GID"
        if ! change_group_id "${group}" "$GROUP_ID"; then
            FAILURE='true'
            myexit
        fi
    fi
else
    log "info" "${group} does not exist - creating with GID $GROUP_ID"
    if ! create_group  "${group}" "$GROUP_ID"; then
        FAILURE='true'
        myexit
    fi
fi

is_${user}_valid="true"
log "info" "Verifying ${user} user exists and has proper UID"
if grep -q ^${user}: /etc/passwd; then
    log "info" "${user} user exists - checking UID"
    is_${user}_uid=$(grep ^${user}: /etc/passwd | cut -d ":" -f 3)
    if [[ "$is_${user}_uid" == "$USER_UID" ]]; then
        log "info" "${user} user has proper UID ($USER_UID)"
    else
        log "warn" "${user} user has different UID - changing"
        if ! change_user_id "${user}" "$USER_UID"; then
            FAILURE='true'
            is_${user}_valid="false"
            myexit
        fi
    fi
else
    log "info" "User ${user} does not exist - creating with UID $USER_UID"
    if ! create_user "${user}" "$USER_UID"; then
        FAILURE='true'
        is_${user}_valid="false"
        myexit
    fi
fi

if [[ "$is_${user}_valid" == "true" ]]; then
    log "info" "Making sure user ${user} has the proper groups associated"
    log "info" "Running usermod ${user} -g ${group} ${user}"
    if ! usermod -g ${group} ${user} ; then
        FAILURE='true'
        log "error" "Failed to associate proper groups to ${user} user"
        myexit
    else
        log "info" "Proper groups associated to user ${user}"
    fi
fi

log "info" "Creating /home/${user}/.ssh directory"
if ! mkdir -p /home/${user}/.ssh ; then
    log "error" "Failed creating /home/${user}/.ssh directory"
    FAILURE='true'
    myexit
else
    log "info" "Adding ssh public key to '${user}' authorized hosts"
    echo "$SSH_PUB_KEY" >> /home/${user}/.ssh/authorized_keys
fi

log "info" "Setting .ssh directory and contents correct permissions"
chown -R ${user}:${group} /home/${user}/.ssh
chmod 700 /home/${user}/.ssh
chmod 600 /home/${user}/.ssh/authorized_keys
