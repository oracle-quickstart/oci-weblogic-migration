

Use LibraryHelper to extract all libraries into restored model


#Use https://github.com/mlinxfeld/terraform-oci-private-dns  for private dns when nodemanager or wls servers are using hostnames.
# This depends on Adao's code.

check file_template_helper.py  and its methods.
review target_configuration_helper.py  to generate oci configuration

use json_translator.py  methods to deal with json to python files or js

[#TODO]
export WLS_MIG_HOME=/home/opc/mig
export WDT_CUSTOM_CONFIG=$WLS_MIG_HOME/wdtconfig
export WLS_MIG_OUTPUT=$WLS_MIG_HOME/output


#TODO Start with model mapping
# extend model_preparer as oci_model_prerarer and overwrite prepare_models method to be OCI migration related
# use targetr_configuration_helper.py to generate oci configuration
# convert python to json_translator.py methods to deal with json to python files or js


#TODO Files to update after migration
# domain config.xml with new settings.
# /opt/middleware/wlserver/../oracle_common/common/nodemanager/nodemanager.properties  if it lives under middleware home.

#TODO Exclude certain files from tar file ?
# exclude_wls_private_config  = .snapshot
#                               servers/*/data/nodemanager/*.lck
#                               servers/*/data/nodemanager/*.pid
#                               servers/*/data/nodemanager/*.state
#                               servers/*/tmp
#                               servers/*/adr
#                               nodemanager/*.id
#                               nodemanager/*.lck
#                               tnsnames.ora


#TODO:  Aug 13th
#- Check block volume names
# module.compute.module.middleware_volume_attach.oci_core_volume_attachment.these["-block-volume-attach-01"] will be created
# + resource "oci_core_volume_attachment" "these" {
# + attachment_type                     = "iscsi"
# + availability_domain                 = (known after apply)
# + chap_secret                         = (known after apply)
# + chap_username                       = (known after apply)
# + compartment_id                      = (known after apply)
# + device                              = (known after apply)
# + display_name                        = "-block-volume-attach-1"
##########
#- Check block volume mount points
#- Update Loadbalancer IP addresses
# Warning: Deprecated attribute
# │
# │   on modules/lb/loadbalancer/outputs.tf line 10, in output "wls_loadbalancer_ip_addresses":
# │   10:   value       = oci_load_balancer_load_balancer.wls_loadbalancer.ip_addresses
# │
# │ The attribute "ip_addresses" is deprecated. Refer to the provider documentation for details.


#TODO: Sept 11
# Configure only domain volume
# Add input to define volume size in schema.yaml
# Restore all other archives in /   . Analyze if tree path depends on each other archive to restore to determine order.