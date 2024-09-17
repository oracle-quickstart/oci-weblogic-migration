#!/usr/bin/env bash

# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#############################################################################################################################
# Name                 : check_pre-reqs.sh
# Description          : Check minium requirements to run OCI Weblogic Migration Tool
#############################################################################################################################

###################################################### Requirements #########################################################

expected_os_name_oracle="oracle linux server"
expected_os_name_rhel="red hat enterprise linux"
minimum_os_version_oracle="8.0"
minimum_os_version_rhel="8.0"
minimum_cpu_count=8
minimum_mem_in_gib=8
expected_system_disk_partition_table_type="gpt"
minimum_system_disk_size_human_readable="80Gi"
minimum_data_disk_size_human_readable="100Gi"
minimum_root_size_human_readable="2Gi"
minimum_home_size_human_readable="4Gi"
minimum_tmp_size_human_readable="3Gi"
minimum_var_size_human_readable="50Gi"
minimum_usr_size_human_readable="8Gi"

###################################################### Script setup #########################################################

set -Eeuo pipefail

if [[ $(uname | tr '[:upper:]' '[:lower:]') != "linux" ]]; then
    echo "This script can only be run on a Linux environment, but environment type $(uname) was detected."
    exit 1
fi

if [[ $(/usr/bin/id -u) -eq 0 ]]; then
    echo "No need to run this as root user.  Please run it with a non-root user"
    exit 1
fi

errors=()

function report_and_exit() {
    echo
    if [ ${#errors[@]} != 0 ]; then
        echo "Found the following errors..."
        for error in "${errors[@]}"; do
            echo "    • $error"
        done
        exit 1
    else
        echo "No errors were found!"
        exit 0
    fi
}

section_start_error_count=0

function start_section() {
    section_start_error_count=${#errors[@]}
    printf "    Checking %s requirements... " "$1"
}

function end_section() {
    if [[ $section_start_error_count -eq ${#errors[@]} ]]; then
        echo "OK"
    else
        echo "FAIL"
    fi
}


####################################################### OS checks ###########################################################

start_section "OS"

if ls /etc/*-release 1> /dev/null 2>&1; then
    os_name=$(cat /etc/*-release | grep "^NAME=" | cut -d'"' -f2 | tr '[:upper:]' '[:lower:]')
    os_version=$(cat /etc/*-release | grep "^VERSION_ID=" | cut -d= -f2 | xargs)

    if [ "$os_name" == "$expected_os_name_oracle" ] || [ "$os_name" == "$expected_os_name_rhel" ]; then
        if [[ -z "${os_version// }" ]]; then
            errors+=("The $os_name version could not be detected. Redgate Clone requires at least version $minimum_os_version.")
        else
            is_rhel8=
            if [ "$os_name" == "$expected_os_name_oracle" ]; then
                minimum_os_version=$minimum_os_version_oracle
            else
                minimum_os_version=$minimum_os_version_rhel
                major_version=$(printf %.1s "$os_version")
                if [ "$major_version" == "8" ]; then
                    is_rhel8=true
                fi
            fi

            if [[ $(printf "%s\n%s" "$minimum_os_version" "$os_version" | sort -V | head -n1) != "$minimum_os_version" ]]; then
                errors+=("The $os_name version must be at least $minimum_os_version but was detected to be $os_version.")
            fi
        fi
    else
        errors+=("The operating system must be $expected_os_name_rhel or $expected_os_name_oracle but it was detected to be $os_name.")
        end_section
        report_and_exit # Exit early as the other checks may not work as expected.
    fi
else
    errors+=("The operating system must be $expected_os_name_rhel or $expected_os_name_oracle but the distribution could not be detected. The uname command returns \"$(uname -a)\".")
    end_section
    report_and_exit # Exit early as the other checks may not work as expected.
fi

end_section

#################################################### Hardware checks ########################################################

start_section "CPU"

cpu_count=$(nproc --all)

if [ "$cpu_count" -lt "$minimum_cpu_count" ]
then
    errors+=("Redgate Clone requires a minimum of $minimum_cpu_count vCPUs, but $cpu_count were detected.")
fi

end_section

start_section "RAM"


# mem_in_gib=$(awk '/MemFree/ { printf "%.3f \n", $2/1024/1024 }' /proc/meminfo)
mem_in_gib=$(free -m | sed -n 's/^Mem:\s\+[0-9]\+\s\+\([0-9]\+\)\s.\+/\1/p')
mem_in_gib="${mem_in_gib//[$'\t\r\n ']}"
# mem_in_gib=`expr $mem_in_gib + 1`
if [ "$mem_in_gib" -lt "$minimum_mem_in_gib" ]; then
    errors+=("At least  ${minimum_mem_in_gib}Gi RAM required, but ${mem_in_gib}Gi was detected.")
fi


end_section

################################################# Internet connectivity #####################################################

start_section "Internet connectivity"

set +e
if ! curl --silent --head --retry 3 --output /dev/null https://www.oracle.com/; then
    errors+=("Internet connectivity to oracle.com was not detected. Export Proxy settings if needed. ")
fi

if ! curl --silent --head --retry 3 --output /dev/null https://cloud.oracle.com/; then
    errors+=("Internet connectivity to Oracle Cloud was not detected. Export Proxy settings if needed.")
fi

if ! curl --silent --head --retry 3 --output /dev/null https://login.oci.oraclecloud.com/; then
    errors+=("Internet connectivity to Oracle Cloud was not detected. Export Proxy settings if needed.")
fi

set -e

end_section

################################################# Required Packages #####################################################

start_section "Required Packages"

set +e

if ! which python 2>&1 > /dev/null; then
    errors+=("Unable to find python ")
fi

if ! rpm -qa | grep -i 'python.*oci' 2>&1 > /dev/null; then
    errors+=("Unable to find OCI Python client library")
fi


if ! rpm -qa | grep -i 'sshpass' 2>&1 > /dev/null; then
    errors+=("Unable to find OCI Python client library")
fi


if ! rpm -qa | grep -i python3-paramiko 2>&1 > /dev/null; then
    errors+=("Unable to find Paramiko Python SSH client library")
fi

if ! which jq 2>&1 > /dev/null; then
    errors+=("Unable to find jq. For more information see https://jqlang.github.io/jq/download/")
fi



set -e

end_section

################################################ Kernel configuration values  ####################################################


# pip install virtualenv

# virtualenv oci_sdk_env
# source oci_sdk_env/bin/activate

# pip install oci

# readonly OCI_SDK_PYTHON_DOC_URL=https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/pythonsdk.htm

# if ! curl --silent --head --retry 3 --output /dev/null $INSTALLATION_TEST_URL; then
#     errors+=("Unable to reach the URL hosting the installation script: $INSTALLATION_TEST_URL.")
# fi

# start_section "Kernel configuration"

# max_user_instances=$(sysctl fs.inotify.max_user_instances | awk '{print $NF}')

# if [ "$max_user_instances" -lt 512 ]
# then
#     errors+=("The kernel configuration fs.inotify.max_user_instances should be set to at least 512 but was detected to be $max_user_instances.")
# fi

# max_io_request=$(sysctl fs.aio-max-nr | awk '{print $NF}')

# if [ "$max_io_request" -lt 1048576 ]
# then
#     errors+=("The kernel configuration fs.aio-max-nr should be set to at least 1048576 but was detected to be $max_io_request.")
# fi

# end_section

################################################ Report findings to user ####################################################

report_and_exit