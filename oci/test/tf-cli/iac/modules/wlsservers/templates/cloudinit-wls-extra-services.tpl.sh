#!/bin/bash
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

fileName=$(basename $BASH_SOURCE)

function get_logs_dir {
  response_code=$(curl  --write-out '%{http_code}' --silent --output /dev/null -H "Authorization:Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/logs_dir)
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
log_file="$${logs_dir}/bootstrap.log"

function log() {
    while IFS= read -r line; do
        DATE=`date '+%Y-%m-%d %H:%M:%S.%N'`
        echo "<$DATE>  $line"
    done
}

# Pre-create provisioning log as ${user} user so it is owned by ${user} user.
# This is to avoid race-condition if logging happens from a script running as root user first then
# provisioning log is created and owned by root user. So we pre-create it before any logging happens
# to provisioning log file.
sudo su - ${user} -c "touch $${logs_dir}/provisioning.log"
# grant write permission to the opc user for the log file. This is required for cloning operation.
sudo su - ${user} -c "chmod 777 $${logs_dir}"
sudo su - ${user} -c "chmod a+w $${logs_dir}/provisioning.log"

# Unzip vmscript first, if any error from mountVolume, check_provisioning_status & troubleshooting
# scripts will process error accordingly
echo "Executing unpack vmscript script" | log >> $log_file

python3 /opt/scripts/unzip_vmscript.py | log >> $log_file
exit_code=$${PIPESTATUS[0]}

if [ $exit_code -ne 0 ]; then
    echo "Error executing vmscripts unpack.. Exiting provisioning" | log >> $log_file
    #clean up script
    /opt/scripts/tidyup.sh
    exit 1
fi

echo "Executed vmscripts unpack script with exit code [$exit_code]" | log >> $log_file

# Call bootstrap.py (part of wls image) to unzip fmiddleware and jdk zips
# after volumes are set up, unpacks fmw/jdk zips

python3 /opt/scripts/dbconnection.py | log >> $log_file

# Ensure they are owned by ${user} user and the shell scripts have execute file permission.
sudo chown -R ${user}:${group} /u01
sudo chmod -R 775 /u01/
sudo chown -R ${user}:${group} /opt
sudo chmod -R 775 /opt/
sudo chmod +x /opt/scripts/*.sh


# Append to ${user} home bashrc so DOMAIN_HOME is configured for ${user} user - this is required for migration
WLS_DOMAIN_NAME=${domain}
WLS_DOMAIN_DIR=${domain_dir}
DOMAIN_HOME=$WLS_DOMAIN_DIR"/"$WLS_DOMAIN_NAME
echo "export DOMAIN_HOME=$${DOMAIN_HOME}" >> /home/${user}/.bashrc

sudo su - ${user} -c "df -h" | log >> $log_file


# vm validators - fail fast scenarios
echo "Executing validator script" | log >> $log_file
validator_script_output=$(sudo su ${user} -c 'python3 /opt/scripts/validator.py 2>&1')
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "$validator_script_output" | log  >> $log_file
  echo "VM validators failed. Exiting" | log >> $log_file
  #clean up script
  /opt/scripts/tidyup.sh
  exit 1
fi

echo "Executed validator script with exit code [$exit_code]" | log >> $log_file

# Continue with initialization and append to the provisioning log both stdout and stderr

#check versions in prod version
echo "Executing check_versions script" | log >> $log_file

/opt/scripts/check_versions.sh
exit_code=$?

echo "Executed check_versions script with exit code [$exit_code]" | log >> $log_file

if [ $exit_code -eq 0 ]; then
    config_script="/opt/scripts/idcs/configure_test_idcs.sh"
    [[ -x $${config_script} ]] && $${config_script}
    rm -f $${config_script}

    has_idcs_artifacts_admin_host=0
    is_admin_instance=$(sudo su ${user} -c 'python3 /opt/scripts/databag.py is_admin_instance')
    lb_backend_state="False"
    if [ "$is_admin_instance" = "true" ]; then
        # Secured production mode SSL management
        if [ $exit_code -eq 0 ]; then
            configure_secure_mode=$(sudo su ${user} -c 'python3 /opt/scripts/databag.py configure_secure_mode')
            if [[ "$configure_secure_mode" == "true" ]]; then
                echo "Executing custom SSL setup script" | log >> $log_file
                custom_ssl_setup_log=$(sudo su - ${user} -c 'python3 /opt/scripts/secure_mode_ssl_management.py')
                exit_code=$?
                echo $custom_ssl_setup_log | log >> $log_file
                if [ $exit_code -eq 0 ]; then
                  echo "Executed custom SSL setup script with exit code [$exit_code]" | log >> $log_file
                else
                  echo "Failed to execute custom SSL setup script. Exiting with error_code=$exit_code" | log >> $log_file
                  #clean up script
                  /opt/scripts/tidyup.sh
                  # Creating failure marker
                  python3 /opt/scripts/markers.py create-failure-marker /u01/domainCreatedMarker "Failed to execute custom SSL setup script"
                  exit 1
                fi
            fi
        fi
        if [ $exit_code -eq 0 ]; then
            echo "Executing terraform_init.sh" | log >> $log_file
            su - ${user} -c /opt/scripts/terraform_init.sh
            exit_code=$?
            echo "Executed terraform_init.sh with exit code [$exit_code]" | log >> $log_file
            # grant world rwx permissions for the log directory. This is required for the cloning operation, which is executed by 'opc' user.
            chmod 777 /u01/logs ; touch /u01/logs/provisioning.log ; chown ${user}:${group} /u01/logs/provisioning.log ; chmod a+rw /u01/logs/provisioning.log ; chmod 777 /opt/scripts/clogging/*
        fi
    else
      # Managed Server
        #Create the markers if customer has opted for manual domain extension
        if [ $allow_manual_domain_extension  == 'true' ]; then
            python3 /opt/scripts/markers.py create-success-marker "/u01/domainCreatedMarker" "Skipping domain extension for managed server as it was not requested." "false"
            python3 /opt/scripts/markers.py create-success-marker "/u01/managedServerStarted" "Skipping managed server startup as it was not requested." "false"

            WLS_DOMAIN_DIR=$(python3 /opt/scripts/databag.py domain_dir)
            WLS_DOMAIN_NAME=$(python3 /opt/scripts/databag.py wls_domain_name)
            WLS_DOMAIN_HOME=$WLS_DOMAIN_DIR"/"$WLS_DOMAIN_NAME

            touch "$${WLS_DOMAIN_HOME}/provCompletedMarker"
            lb_backend_state="True"

            #LB backend is created in offline state
            #This is setting it to the correct state based on node
            add_loadbalancer=$(python3 /opt/scripts/databag.py add_loadbalancer)
            if [ $${add_loadbalancer} == 'true' ]; then
                load_balancer_id=$(python3 /opt/scripts/databag.py load_balancer_id)
                resource_prefix=$(python3 /opt/scripts/databag.py service_name)
                backend_set_name=$${resource_prefix}-lb-backendset
                ip=$(hostname -i)
                port=$(python3 /opt/scripts/databag.py wls_ms_extern_port)

                backend_name=$${ip}":"$${port}

                echo "Setting loadbalancer backend offline state : $${load_balancer_id}, $${backend_set_name}, $${backend_name} $${lb_backend_state}" | log >> $log_file
                python3 /opt/scripts/oci_api_utils.py update_lb_backend_offline_state $${load_balancer_id} $${backend_set_name} $${backend_name} $${lb_backend_state}
                exit_code=$?
                if [ $exit_code -ne 0 ]; then
                    echo "Failed to change the state of the Load balancer backend for this node [$exit_code]" | log >> $log_file
                fi
            fi
        fi
    fi

#    echo "Copying wls.service to systemd.." | log >> $log_file
#    sudo cp /opt/scripts/wls.service /usr/lib/systemd/system
#    echo "Creating symlink for wls.service" | log >> $log_file
#    sudo ln -s '/usr/lib/systemd/system/wls.service' '/etc/systemd/system/multi-user.target.wants/wls.service'

fi

# grant write permission to the opc user for the log file. This is required for cloning operation.
sudo su - ${user} -c "chmod 777 $${logs_dir}"
sudo su - ${user} -c "chmod a+w $${logs_dir}/provisioning.log"

echo "Executing cleanup script" | log >> $log_file

#clean up script
/opt/scripts/tidyup.sh

echo "Executed cleanup script" | log >> $log_file
