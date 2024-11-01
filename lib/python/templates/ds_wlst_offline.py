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
    except Exception, ex:
        dumpStack()

def enable_wallet(ds,wallet_path):
    ds_path='/JDBCSystemResource/'+ds+'/JdbcResource/'+ds+'/JDBCDriverParams/NO_NAME_0/'
    prop_path=ds_path+'Properties/NO_NAME_0/'
    try:
        cd(ds_path)
        createEntityIfDoesntExists(ds_path,'Properties')
    except Exception, e:
        #logger.error("0063", str(e))
        print("Properties d")
        dumpStack()
    try:
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','propertyFan')
        cd('Property/propertyFan')
        set("Name", "oracle.jdbc.fanEnabled")
        set("Value", "false")
    except Exception, e:
        #logger.error("0063", str(e))
        print("Failed to create Propertie fanEnabled")
        dumpStack()
    try:
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','propertyTnsAdmin')
        # create('propertyTnsAdmin','Property')
        cd('Property/propertyTnsAdmin')
        set("Name", "oracle.net.tns_admin")
        set("Value", wallet_path)
    except Exception, e:
        #logger.error("0063", str(e))
        print("Failed to create Propertie tns_admin")
        dumpStack()
    try:
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','propertySSLVersion')
        cd('Property/propertySSLVersion')
        set("Name", "oracle.net.ssl_version")
        set("Value", "1.2")
    except Exception, e:
        #logger.error("0063", str(e))
        print("Failed to create Propertie ssl_version")
        dumpStack()
    try:
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','propertySSLDNMatch')
        cd('Property/propertySSLDNMatch')
        set("Name", "oracle.net.ssl_server_dn_match")
        set("Value", "true")
    except Exception, e:
        #logger.error("0063", str(e))
        print("Failed to create Propertie ssl_server_dn_match")
        dumpStack()
    try:
        cd(prop_path)
        createEntityIfDoesntExists(prop_path,'Property','propertyWalletLocation')
        cd('Property/propertyWalletLocation')
        set("Name", "oracle.net.wallet_location")
        set("Value", wallet_path)
    except Exception, e:
        #logger.error("0063", str(e))
        print("Failed to create Propertie wallet_location")
        dumpStack()
    ls()
    updateDomain()

readDomain('/opt/domains/testdomain/')
enable_wallet("JDBC Data Source-Test3","/opt/domains/testdomain/wlsdeploy/config/wallets/ocid.wallet_a")
closeDomain()
exit()