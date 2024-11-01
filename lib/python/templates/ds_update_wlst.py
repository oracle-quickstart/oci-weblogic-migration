"""
# Copyright (c) 2024, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
"""
import os
import socket as pysocket
import sys
import traceback
#sys.path.append("/opt/scripts/")
#sys.path.append("/opt/scripts/clogging")
#exec(open("/opt/scripts/wlstUtils.py").read())

#logger = commonLogging.getLogger("ds_o2.py")

def createEntityIfDoesntExists(parent_location, kclass, name="NO_NAME_0"):
    try:
        cd(parent_location)
        current_contents = ls(returnMap='true')
        if current_contents is None or kclass not in current_contents:
            create(name, kclass)
            print("entity created: "+kclass+"/"+name)
    except Exception, ex:
        print("exception caught here.. "+ str(ex))
        dumpStack()

def enable_wallet(ds,wallet_path):
    ds_path='/JDBCSystemResource/'+ds+'/JdbcResource/'+ds+'/JDBCDriverParams/NO_NAME_0/'
    prop_path='/JDBCSystemResources/' + ds + '/JdbcResource/' + ds + '/JDBCDriverParams/NO_NAME_0' + '/Properties/NO_NAME_0'
    try:
        cd(ds_path)
        createEntityIfDoesntExists(ds_path,'Properties',ds)
        print('Properties entity created')
    except Exception, e:
        #logger.error("0063", str(e))
        print("Exception creating Properties d "+str(e))
    try:
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','oracle.jdbc.fanEnabled')
        cd(prop_path+'/Property/oracle.jdbc.fanEnabled')
        cmo.setValue("false")
        print("jbdc Fan Enabled property created")
        ###
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','oracle.net.ssl_server_dn_match')
        # create('oracle.net.ssl_server_dn_match','Property')
        cd(prop_path+'/Property/oracle.net.ssl_server_dn_match')
        cmo.setValue("true")
        print("ssl server dn match property created")
        ###
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','oracle.net.tns_admin')
        # create('oracle.net.tns_admin','Property')
        cd(prop_path+'/Property/oracle.net.tns_admin')
        cmo.setValue(wallet_path)
        print("tns_admin property created")
        ##
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','oracle.net.ssl_version')
        # create('oracle.net.ssl_version','Property')
        cd(prop_path+'/Property/oracle.net.ssl_version')
        cmo.setValue("1.2")
        print("ssl_version property created")
        ## Wallet Location
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','oracle.net.wallet_location')
        # create('oracle.net.wallet_location','Property')
        cd(prop_path+'/Property/oracle.net.wallet_location')
        cmo.setValue(wallet_path)
        print("wallet_location property created")
    except Exception, e:
        print(str(e))
        dumpStack()
        return
    cd(prop_path)
    ls('a')
    print("updating domain")
    updateDomain()

readDomain('/opt/domains/testdomain/')
enable_wallet("JDBC Data Source-Test3","/opt/domains/testdomain/wlsdeploy/config/wallets/ocid.wallet_a")
print("closing domain...")
closeDomain()
exit()
