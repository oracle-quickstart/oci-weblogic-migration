#!/usr/bin/env bash

# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

#############################################################################################################################
# Name                 : check_pre-reqs.sh
# Description          : Check minium requirements to run OCI Weblogic Migration Tool
#############################################################################################################################

scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.." ||exit; pwd)

###################################################### Requirements #########################################################

expected_os_name_oracle="oracle linux server"
expected_os_name_rhel="red hat enterprise linux"
minimum_os_version_oracle="8.0"
minimum_os_version_rhel="8.0"
# Setting minimum CPU to 1 for now, as stacks are being created with 1 or 2 OCPUs.
# This avoids blocking execution. We can update this threshold later.
minimum_cpu_count=1
#minimum_cpu_count=8
minimum_mem_in_gib=8

###################################################### Script setup #########################################################

set -Eeuo pipefail

if [[ $(uname | tr '[:upper:]' '[:lower:]') != "linux" ]]; then
    echo "This script can only be run on a Linux environment, but environment type $(uname) was detected."
    exit 1
fi

if [[ $(/usr/bin/id -u) -eq 0 ]]; then
    echo "No need to run this as root user. Please run it with a non-root user"
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


mem_in_gib=$(free -m | sed -n 's/^Mem:\s\+[0-9]\+\s\+\([0-9]\+\)\s.\+/\1/p')
mem_in_gib="${mem_in_gib//[$'\t\r\n ']}"
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

################################################# on-prem.env Parameter Checks #####################################################

start_section "on-prem.env parameters"

set +e

env_file="$toolHome/config/on-prem.env"

# Check if the environment file exists
if [ ! -f "$env_file" ]; then
    errors+=("The required environment file $env_file was not found.")
else
    declare -A env_vars
    # Read each line from the env file that contains '='
    while IFS='=' read -r key value; do
        key=$(echo "$key" | xargs)   # Trim whitespace
        value=$(echo "$value" | xargs)
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        env_vars["$key"]="$value"
    done < <(grep '=' "$env_file")

    # Always-required keys
    required_keys=("ssh_user" "domain_home" "oracle_home" "skip_transfer")

    # Track missing keys
    missing_keys=()
    for key in "${required_keys[@]}"; do
        if [[ -z "${env_vars[$key]:-}" ]]; then
            errors+=("Missing value or key '$key' in $env_file.")
            missing_keys+=("$key")
        fi
    done

    # Extra required keys if skip_transfer=false
    if [[ "${env_vars[skip_transfer]}" == "false" ]]; then
        extra_keys=("bucket_name" "compartment_ocid" "tenancy_namespace")
        for key in "${extra_keys[@]}"; do
            if [[ -z "${env_vars[$key]:-}" ]]; then
                errors+=("Missing value or key '$key' in $env_file (required when skip_transfer=false).")
                missing_keys+=("$key")
            fi
        done
    fi

    # Check if the directory specified by domain_home exists
    if [[ -n "${env_vars[domain_home]:-}" && ! -d "${env_vars[domain_home]}" ]]; then
        errors+=("The path specified for 'domain_home' (${env_vars[domain_home]}) does not exist or is not accessible by the current user ($(whoami)). Please check the permissions or update the path in $env_file.")
    fi

    # Check if the directory specified by oracle_home exists
    if [[ -n "${env_vars[oracle_home]:-}" && ! -d "${env_vars[oracle_home]}" ]]; then
        errors+=("The path specified for 'oracle_home' (${env_vars[oracle_home]}) does not exist or is not accessible by the current user ($(whoami)). Please check the permissions or update the path in $env_file.")
    fi

    # Ensure at least one SSH authentication method is set
    if [[ -z "${env_vars[ssh_private_key_file]:-}" && -z "${env_vars[ssh_password_file]:-}" ]]; then
        errors+=("Either 'ssh_private_key_file' or 'ssh_password_file' must be set in $env_file.")
    fi

    # Check if the ssh_private_key_file exists if specified
    if [[ -n "${env_vars[ssh_private_key_file]:-}" && ! -f "${env_vars[ssh_private_key_file]}" ]]; then
        errors+=("The file specified for 'ssh_private_key_file' (${env_vars[ssh_private_key_file]}) does not exist or is not accessible by the current user ($(whoami)). Please check the permissions or update the path in $env_file.")
    fi

    # Check if the ssh_password_file exists if specified
    if [[ -n "${env_vars[ssh_password_file]:-}" && ! -f "${env_vars[ssh_password_file]}" ]]; then
        errors+=("The file specified for 'ssh_password_file' (${env_vars[ssh_password_file]}) does not exist or is not accessible by the current user ($(whoami)). Please check the permissions or update the path in $env_file.")
    fi

    # Check if skip_transfer value is valid or not (valid values: true or false)
    if [[ "${env_vars[skip_transfer]}" != "false" && "${env_vars[skip_transfer]}" != "true" ]]; then
        errors+=("skip_transfer value in the $env_file can be true or false")
    fi
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


# Only check for sshpass if ssh_password_file is used in on-prem.env
if [[ -n "${env_vars[ssh_password_file]:-}" ]]; then
    if ! rpm -q sshpass > /dev/null 2>&1; then
        errors+=("Unable to find sshpass package")
    fi
fi

set -e

end_section

################################################ OCI CLI Pre-Check ####################################################

start_section "OCI CLI Pre-Check"

# allow failures in this block
set +e

# only do the check if skip_transfer is "false"
if [ "${env_vars[skip_transfer]}" = "false" ]; then

  # make sure oci is on $PATH
  if ! oci > /dev/null 2>&1; then
    errors+=("Oracle Cloud Infrastructure CLI (oci) not found in the path.")
  fi

  # make sure oci is configured for the current ssh user
  if ! echo n |oci iam region list > /dev/null 2>&1; then
    errors+=("Failed to verify OCI CLI is configured. For more information visit: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm")
  fi

fi

set -e

end_section

################################################ Report findings to user ####################################################

report_and_exit