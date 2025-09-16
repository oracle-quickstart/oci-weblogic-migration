# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

from wlsdeploy.util import cla_helper
def filter_model(model):
   if model and 'topology' in model:
       admin_server_name = model['topology']['AdminServerName']
       # 'AdministrationPort'

       # Defaults to 7001
       if not 'ListenPort'  in model['topology']['Server'][admin_server_name]:
           model['topology']['Server'][admin_server_name]['ListenPort']=7001
       # Defaults SSL to 7002
       if not 'ListenPort'  in model['topology']['Server'][admin_server_name]["SSL"]:
           model['topology']['Server'][admin_server_name]['SSL']['ListenPort']=7002

       # if 'AdministrationPortEnabled' in model['topology']['Server'][admin_server_name] and model['topology']['Server'][admin_server_name]['AdministrationPortEnabled']== True:
       print('AdministrationPortEnabled')
       print(model['topology']['AdministrationPortEnabled'])
       if 'AdministrationPortEnabled' in model['topology'] and model['topology']['AdministrationPortEnabled']:
            if not "AdministrationPort" in model['topology']['Server'][admin_server_name]:
                model['topology']['Server'][admin_server_name]['AdministrationPort']=9002

       print('WMT filter model completed')
       # listen_port = {
       #  "topology": {
       #          "Server": {
       #              admin_server_name: {
       #                  "ListenPort": 7001
       #              }
       #          }
       #     }
       # }
       # # no variables are needed to resolve this
       # print('Before merging')
       # cla_helper.merge_model_dictionaries(model, listen_port, None)
       # print('After merging')
       # print("Merged model: " + str(dictionary))
#export WDT_CUSTOM_CONFIG=/home/domain/mig/wdtconfig
# secured_production_mode=false
# # Set this to true to force a domain wide administration port. Otherwise, the above port will be set only for the admin server.
# secured_production_set_domain_wide=false
# # If the below property is not set to a value (empty string) then the port won't be set and 9002 will be used by default.
# secured_production_domain_wide_port=
# # Set below to true to indicate that the administrative port should be set for the admin server.
# secured_production_override_domain_wide_port=true
# # If the below property is not set to a value (empty string) then the port won't be set and 9002 will be used by default.
# # This value will override the domain wide port.
# secured_production_admin_port=9875