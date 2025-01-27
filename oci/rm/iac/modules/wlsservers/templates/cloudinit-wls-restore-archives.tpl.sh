#!/usr/bin/env bash
# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
# shellcheck disable=SC1091

#USER=${user}

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
log_file="$${logs_dir}/wls-restore.log"


function log(){
    while IFS= read -r line; do
            DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
            echo "<$DATE>  $line"
    done
}

function check_device() {
    local device=$1
    if blkid $device | egrep 'TYPE=\"ext' > /dev/null ; then
        echo "check_device: $device has a file system"
        return 0
    fi
    return 1
}

function format_fs(){
    local point=$1
    local device=$2

    failed=true
    if check_device $device; then
        echo "<WARNING - execute_mount:found existing file system>"
        df | egrep $device
        df | egrep $device > /dev/null || e2fsck -p $device 2>&1
        result=$?
        echo "df| egrep $device returned code [$result]"
        if [ $result -ge 2 ]; then
            echo "ERROR : <execute_mount:command failed:$${result}: e2fsck -p $device. mountpoint $point not initialized>"
            failed=true
        else
            echo "execute_mount: e2fsck passed"
            failed=false
        fi
    else
        echo "execute_mount: creating ext4 filesystem for $device"

        mkfs.ext4 -v -F $device
        status=$?

        echo "execute_mount: status of cmd[mkfs.ext4] = $status"
        count=1
        while [ $status -ne 0 -a $count -lt 10 ]; do
            let count=count+1
            echo "execute_mount: Retrying mkfs.ext4 $device"
            mkfs.ext4 -v -F $device
            status=$?
            sleep 10
            echo "execute_mount: status of cmd[mkfs.ext4] ==>$status"
        done

        if [ $status -eq 0 ]; then
            echo "execute_mount: tuning ext4 filesystem for $device"

            tune2fs -e remount-ro $device 2>&1
            status=$?

            if [ $status -eq 0 ]; then
                failed=false
            else
                dmesg | tail
                echo "execute_mount: cmd[tune2fs] returned status $status"
            fi
        else
            dmesg | tail
            echo "execute_mount: cmd[mkfs.ext4] returned status=$status"
        fi
    fi

    if [ $failed == "false" ]; then
        mkdir -p $point
        echo "df | egrep $device"
        df | egrep $device
        retVal=$?
        echo "df and egrep command returned [$retVal]"
        if [ $retVal -ne 0 ]; then
            echo "execute_mount: mounting $device at $point"

            mount -t ext4 $device $point
            success=$?

            if [ $success -eq 0 ]; then
                echo "execute_mount: Successfully mounted $device at $point"
                mountpoint $point
                if [ $? -ne 0 ]; then
                    echo "execute_mount: ERROR - $point is not a mountpoint"
                    return 1
                else
                    echo "execute_mount: change ownership and permission on newly mounted volume. "
                    chown -R ${user}:${group}  $point
                    chmod -R 775 $point
                    return 0
                fi
            fi
        else
            echo "execute_mount: ERROR - mount was not executed as cmd[tune2fs] failed"
            return 0
        fi
    else
        echo "execute_mount: ERROR - mount was not executed"
    fi
}


function check_fs(){
   echo "<cloud-init><restore><check_fs> list volumes prior restoring" | log >> $log_file
   df | egrep ${block_volume_jdk_mountpath} && df | egrep ${block_volume_mw_mountpath} && df | egrep ${block_volume_domain_mountpath}
   exit_code=$?
   echo "list devices returned with exit code $[exit_code] " | log >> $log_file
   if [[ $exit_code -ne 0 ]]; then
     echo "<cloud-init><restore><check_fs> volumes not mounted attempting to format and mount again" | log >> $log_file
     format_fs ${block_volume_jdk_mountpath} ${jdk_device_id} | log >> $log_file
     format_fs ${block_volume_mw_mountpath} ${mw_device_id} | log >> $log_file
     format_fs ${block_volume_domain_mountpath} ${domain_device_id} | log >> $log_file
     #mount -a | log >> $log_file
     echo "<cloud-init><restore><check_fs> volumes not mounted and created outside cloud-init" | log >> $log_file
   fi

}

function set_fs_ownership() {
    echo "<cloud-init><set_fs_ownership> Setting ownership to ${user} on mounted volumes" | log >> $log_file
    chown -R ${user}:${group} ${block_volume_domain_mountpath}
    exit_code=$?
    echo "<cloud-init><set_fs_ownership> change ownership on mount point ${block_volume_domain_mountpath} returned with exit code $[exit_code] " | log >> $log_file
    chown -R ${user}:${group} ${block_volume_mw_mountpath}
    exit_code=$?
    echo "<cloud-init><set_fs_ownership> change ownership on mount point ${block_volume_mw_mountpath} returned with exit code $[exit_code] " | log >> $log_file
    chown -R ${user}:${group} ${block_volume_jdk_mountpath}
    exit_code=$?
    echo "<cloud-init><set_fs_ownership> change ownership on mount point ${block_volume_jdk_mountpath} returned with exit code $[exit_code] " | log >> $log_file
    if [ $exit_code -ne 0 ]; then
        echo "<cloud-init><set_fs_ownership><error> Failed to change ownership. Exiting with [$exit_code] " | log >> $log_file
        exit 1
    fi
    echo "<cloud-init><set_fs_ownership> change ownership completed" | log >> $log_file
}

check_fs | log >> $log_file
set_fs_ownership;
python /opt/scripts/restore-archives.py
exit_code=$?
echo $output | log >> $log_file
if [[ $exit_code -ne 0 ]]; then
  echo "<cloud-init><restore><ERROR> Failed to restore WebLogic Archives " | log >> $log_file
  exit 1
fi
echo "Executed restore-archives via ${user} with exit code [$exit_code]" | log >> $log_file
echo "<cloud-init><restore_archives> Restore completed" | log >> $log_file

