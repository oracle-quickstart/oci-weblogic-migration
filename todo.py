

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
