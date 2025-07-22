#!/bin/bash
# Copyright (c) 2024, 2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

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

mkdir -p /opt/scripts
logs_dir=`get_logs_dir`
#no need to recreate again. logs should be created by wls-restore script.
#mkdir -p $${logs_dir}
log_file="$${logs_dir}/datasource_update.log"

function log() {
    while IFS= read -r line; do
        DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
        echo "<$DATE>  $line"
    done
}

# Script to open ingress port 1522 in the subnet of the selected Autonomous Transaction Processing (ATP) Database.
#eval $(oci-metadata --get is_admin_instance --export)
#eval $(oci-metadata --get open_atp_db_port_1522 --export)
#if [ "$is_admin_instance" = "true" ] && [ "$open_atp_db_port_1522" = "true" ]; then
#    output=$(python3 /opt/scripts/open_db_port.py)
#    exit_code=$?
#    echo "Executed script to open ingress port 1522 in db subnet with exit code [$exit_code]" | log >> $log_file
#    echo "$output" | log >> $log_file
#    if [ $exit_code -ne 0 ]; then
#        echo "Error executing the script to open ingress port 1522 in db subnet. " | log >> $log_file
#    fi
#fi

#VCN peering script to update the Weblogic and Database subnet route tables
eval $(oci-metadata --get is_vcn_peering --export)
eval $(oci-metadata --get is_admin_instance --export)
if [ "$is_admin_instance" = "true" ] && [ "$is_vcn_peering" = "true" ]; then
    output=$(python3 /opt/scripts/vcn_peering.py)
    exit_code=$?
    echo "Executed VCN peering script with exit code [$exit_code]" | log >> $log_file
    echo "$output" | log >> $log_file
    if [ $exit_code -ne 0 ]; then
        echo "Error executing VCN peering script. " | log >> $log_file
    fi
fi

cd "${domain_home}/config/jdbc" || (echo "Failed to cd to ${domain_home}/config/jdbc" | log >> $log_file ; exit 1)


%{ for jdbc_string in datasources }
  is_atp=${jdbc_string.is_atp}
  is_oci_db=${jdbc_string.is_oci_db}
  is_custom_jdbc=${jdbc_string.custom_jdbc}
  on_prem_jdbc_string="${jdbc_string.on_prem}"
  oci_jdbc_string="${jdbc_string.oci}"
  if [ $is_atp == "true" ]; then

    open_atp_db_port_1522="${jdbc_string.open_atp_port}"
    atp_db_vcn_compartment_id="${jdbc_string.atp_network_comp}"
    atp_db_vcn_id="${jdbc_string.atp_vcn_id}"
    atp_db_subnet_id="${jdbc_string.atp_subnet_id}"

    #Opening port 1522 in the subnet of the selected Autonomous Transaction Processing (ATP) Database, if the checkbox is checked.
    if [ "$is_admin_instance" = "true" ] && [ "$open_atp_db_port_1522" = "true" ]; then
        output=$(python3 /opt/scripts/open_db_port.py "$atp_db_port" "$atp_db_vcn_compartment_id" "$atp_db_vcn_id" "$atp_db_subnet_id")
        exit_code=$?
        echo "Executed script to open ingress port 1522 in db subnet ${atp_db_subnet_id} with exit code [$exit_code]" | log >> $log_file
        echo "$output" | log >> $log_file
        if [ $exit_code -ne 0 ]; then
            echo "Error executing the script to open ingress port 1522 in db subnet ${atp_db_subnet_id}" | log >> $log_file
            exit 1
        fi
    fi

    #Wallets will be placed in /u01/oracle/wallet/private/<ocid>
    wallet_location=${domain_home}/wlsdeploy/wallet/private/${jdbc_string.db_id}
    echo "<cloud-init><jdbc-datasources><init> creating wallet path $wallet_location" | log >> $log_file
    output=$(sudo -E -u ${user} mkdir -p "$wallet_location")
    echo $output | log >> $log_file
    atp_wallet_password=$(python3 -c'import sys; sys.path.append("/opt/scripts"); import atp_db_util; wallet_password = atp_db_util.get_md5_hash("${jdbc_string.db_id}" + ":" + "${jdbc_string.atp_name}") + "Z%%"; print(wallet_password)')
    wallet_pass_exit_code=$?
    download=$(sudo -E -u ${user} echo "$${atp_wallet_password}" | python3 /opt/scripts/atp_db_util.py ${jdbc_string.db_id} "$wallet_location" 2>&1 )
    download_exit_code=$?
    echo "Executed ATP wallet download and unzip with exit code [$download_exit_code] and [$unzip_oper_exit_code]" | log >> $log_file
    if [[ $wallet_pass_exit_code -ne 0 ]] || [[ $download_exit_code -ne 0 ]]; then
        echo "Error downloading ATP wallet.. Exiting provisioning" | log >> $log_file
        exit 1
    fi
    files=$(grep -il "$on_prem_jdbc_string" "${domain_home}/config/jdbc/"*.xml)
    for file in $files; do
        output=$(python3 /opt/scripts/ds_update_config_xml_w_atp.py "$file" "$wallet_location" "$oci_jdbc_string")
        exit_code=$?
        echo "Executed datasource ATP update on $file with exit code [$exit_code]" | log >> $log_file
        echo "$output" | log >> $log_file
        if [ $exit_code -ne 0 ]; then
            echo "Error executing datasource update for ATP database.. Exiting provisioning" | log >> $log_file
            exit 1
        fi
    done
    # Find if jspconfig files exist and replace jdbc string if found by this database
    connection_url="jdbc:oracle:thin:@${jdbc_string.atp_name}_${jdbc_string.atp_level}?TNS_ADMIN=$wallet_location"
    output=$(sudo -E -u ${user} grep --include=\*.{xml,properties} -rwl "${domain_home}/config/fmwconfig/" -e "$on_prem_jdbc_string" | xargs sed -i "s|$on_prem_jdbc_string|$connection_url|g");
    exit_code=$?
    echo "Executed datasource ATP update on jps-config*.xml with exit code [$exit_code]" | log >> $log_file
    echo "$output" | log >> $log_file
    if [ $exit_code -eq 123 ]; then
                     echo "Non-JRF migration. continuing executing scripts" | log >> $log_file
    elif [ $exit_code -ne 0 ]; then
        echo "Executed datasource ATP update on jps-config*.xml with ATP database.. Exiting provisioning" | log >> $log_file
        exit 1
    fi

  elif [[ $is_atp == "false" ]] && [[ $is_oci_db == "true" ]]; then

    open_oci_db_port="${jdbc_string.oci_db_create_ingress_sl}"
    oci_db_port="${jdbc_string.oci_port}"
    oci_db_vcn_compartment_id="${jdbc_string.oci_network_comp}"
    oci_db_vcn_id="${jdbc_string.oci_vcn_id}"
    oci_db_subnet_id="${jdbc_string.oci_subnet_id}"

    #Opening port 1522 in the subnet of the selected Autonomous Transaction Processing (ATP) Database, if the checkbox is checked.
    if [ "$is_admin_instance" = "true" ] && [ "$open_oci_db_port" = "true" ]; then
        output=$(python3 /opt/scripts/open_db_port.py "$oci_db_port" "$oci_db_vcn_compartment_id" "$oci_db_vcn_id" "$oci_db_subnet_id")
        exit_code=$?
        echo "Executed script to open ingress port ${oci_db_port} in db subnet ${oci_db_subnet_id} with exit code [$exit_code]" | log >> $log_file
        echo "$output" | log >> $log_file
        if [ $exit_code -ne 0 ]; then
            echo "Error executing the script to open ingress port ${oci_db_port} in db subnet ${oci_db_subnet_id} " | log >> $log_file
            exit 1
        fi
    fi

    files=$(grep -il "$on_prem_jdbc_string" "${domain_home}/config/jdbc/"*.xml)
    for file in $files; do
        output=$(python3 /opt/scripts/ds_update_config_xml_w_db_system.py "$file" "$oci_jdbc_string")
        exit_code=$?
        echo "Executed datasource update $file with exit code [$exit_code]" | log >> $log_file
        echo "$output" | log >> $log_file
        if [ $exit_code -ne 0 ]; then
            echo "Error executing datasource update for DB System database.. Exiting provisioning" | log >> $log_file
            exit 1
        fi
    done
    output=$(sudo -E -u ${user} grep --include=\*.{xml,properties} -rwl "${domain_home}/config/fmwconfig/" -e "$on_prem_jdbc_string" | xargs sed -i "s|$on_prem_jdbc_string|$oci_jdbc_string|g");
    exit_code=$?
    echo "Executed datasource update on jps-config*.xml with exit code [$exit_code]" | log >> $log_file
    echo "$output" | log >> $log_file
    if [ $exit_code -eq 123 ]; then
                 echo "Non-JRF migration. continuing executing scripts" | log >> $log_file
    elif [ $exit_code -ne 0 ]; then
        echo "Error executing datasource update for DB System database on jspconfig files.. Exiting provisioning" | log >> $log_file
        exit 1
    fi
  elif [[ $is_custom_jdbc == "true" ]]; then

        output=$(sudo -E -u ${user} grep --include=\*.{xml,properties} -rwl "${domain_home}/config/jdbc/" -e "$on_prem_jdbc_string" | xargs sed -i "s|$on_prem_jdbc_string|$oci_jdbc_string|g");
        exit_code=$?
        echo "Executed datasource update on $file with exit code [$exit_code]" | log >> $log_file
        echo "$output" | log >> $log_file
        if [ $exit_code -ne 0 ]; then
            echo "Error executing datasource update with custom JDBC connection string on jdbc config files.. Exiting provisioning" | log >> $log_file
            exit 1
        fi
        # Modify jspconfig if exists.
         output=$(sudo -E -u ${user} grep --include=\*.{xml,properties} -rwl "${domain_home}/config/fmwconfig/" -e "$on_prem_jdbc_string" | xargs sed -i "s|$on_prem_jdbc_string|$oci_jdbc_string|g");
         exit_code=$?
         echo "Executed datasource update for custom JDBC connection string on jps-config*.xml with exit code [$exit_code]" | log >> $log_file
         echo "$output" | log >> $log_file
         if [ $exit_code -eq 123 ]; then
             echo "Non-JRF migration. continuing executing scripts" | log >> $log_file
         elif [ $exit_code -ne 0 ]; then
             echo "Error executing datasource update for custom JDBC connection string on jspconfig files.. Exiting provisioning" | log >> $log_file
             exit 1
         fi
  fi

%{ endfor ~}

