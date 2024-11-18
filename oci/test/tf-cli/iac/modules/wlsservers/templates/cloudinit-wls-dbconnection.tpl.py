#
# Copyright (c) 2024 Oracle and/or its affiliates. All rights reserved.
#

import os
import urllib.request
import subprocess
import traceback
import time
import sys


def getAttribute(attribute, default=None):
    """
    Returns attribute or default value if no value is found
    """
    try:
        request_headers = {
            "Authorization": "Bearer Oracle"
        }
        request = urllib.request.Request("http://169.254.169.254/opc/v2/instance/metadata/" + attribute,
                                  headers=request_headers)
        result = urllib.request.urlopen(request).read()
        return result.decode('utf-8')
    except:
        pass

    try:
        result = urllib.request.urlopen('http://169.254.169.254/opc/v1/instance/metadata/' + attribute).read()
        return result.decode('utf-8')
    except:
        pass

    return default

def getMode():
    return getAttribute('mode')

def getVMScriptsPath():
    return getAttribute('vmscripts_path')

def getWlsDomainName():
    return getAttribute("wls_domain_name")

def getIsAdminHost():
    return getAttribute("is_admin_instance")

def getIsATPDB():
    is_atp_db = getAttribute('is_atp_db')
    if is_atp_db is not None and is_atp_db.strip().lower() == "true":
        return True
    return False

def getATPId():
    atp_db_id = getAttribute('atp_db_id')
    return atp_db_id

def isAppDBATPDB():
    is_atp_db = getAttribute('is_atp_app_db')
    if is_atp_db is not None and is_atp_db.strip().lower() == "true":
        return True
    return False

def getAppATPId():
    atp_db_id = getAttribute('app_atp_db_id')
    return atp_db_id

def getLogsDir():
    return getAttribute("logs_dir")

def execute(command):
    """
    Executes a shell command.
    :param command:
    :return:
    """
    log("executing: {0}".format(command))
    exit_status = None
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        out, err = process.communicate()
        exit_status = process.returncode
    except:
        e = sys.exc_info()[0]
        log(e)
        log(err)
    return out, exit_status


def unzip_archive(zip_file, dest='/', already_unzipped_marker_path=None):
    """
    Unzip a zip file to the specified destination directory.

    :param zip_file:
    :param dest:
    :param already_unzipped_marker_path: File or directory used to determine if zip_file has already been unzipped.
    :return:
    """
    status = False
    if os.path.exists(zip_file):
        if not os.path.exists(dest):
            os.makedirs(dest)
        if already_unzipped_marker_path is None or not os.path.exists(already_unzipped_marker_path):
            log('Unzipping zip file [{0}] to destination directory [{1}]'.format(zip_file, dest))
            execute('unzip -o {0} -d {1}'.format(zip_file, dest))
            status = True
        else:
            log('Zip file [{0}] already unzipped in destination directory [{1}]. Unzip skipped.'.format(zip_file, dest))
            status = True
    else:
        log('Zip file not found at [{0}]'.format(zip_file))

    return status

def untar_archive(targz_file, dest = '/'):
    """
    Unarchive the tar.gz file to the specified destination directory.

    :param targz_file:
    :param dest:
    :return:
    """
    status = False
    if os.path.exists(targz_file):
        log('Unpack tar file [{0}]'.format(targz_file))
        execute('tar xvzf {0} -C {1}'.format(targz_file, dest))
        status = True
    else:
        log('Tar file not found at [{0}]'.format(targz_file))

    return status

def log(msg):
    print(msg)

def main():
    """
    This program blocks initiation of provisioning until the provisioning marker files are available on the VM.
    :return: exit status returned is 0 on success, -1 on failure.
    """
    try:
        is_atp_db= getIsATPDB()
        wls_domain_name = getWlsDomainName()
        is_admin_host=False
        if getIsAdminHost().lower()=="true":
            is_admin_host=True

        prov_start_marker = '/u01/provStartMarker'
        prov_completed_marker = '/u01/data/domains/' + wls_domain_name + '/provCompletedMarker'

        # # If provisioning is not already completed
        # # This is to handle post provisioning reboot case when provisioning will have completed already.
        # if not os.path.exists(prov_completed_marker):
        #     #fmw bits
        #     fmiddleware_zip = getFMWZipFile()
        #     fmiddleware_status = unzip_archive(fmiddleware_zip)
        #
        #     #JdK bits
        #     jdk_zip = getJDKZipFile()
        #     jdk_status = unzip_archive(jdk_zip)

        atp_status=True
        if is_atp_db and is_admin_host:
            if os.path.exists(prov_start_marker):
                atp_wallet_zip = '/tmp/atp_wallet.zip'
                if not os.path.exists(atp_wallet_zip):
                    download_atp_cmd='python3 /opt/scripts/oci_api_utils.py download_atp_wallet {0}'.format(getATPId())
                    execute(download_atp_cmd)

                log('Found provisioning start marker for ATP [{0}]'.format(prov_start_marker))
                atp_status = unzip_archive(atp_wallet_zip, dest = '/u01/app/oracle/private/wallet')
            else:
                atp_status=False
                log('Provisioning start marker for ATP was not found. [{0}]'.format(prov_start_marker))

            # # App DB with ATP DB. Download the wallet now
            # if isAppDBATPDB() and is_admin_host:
            #     if os.path.exists(prov_start_marker):
            #         atp_wallet_zip = '/tmp/atp_wallet_appdb.zip'
            #         if not os.path.exists(atp_wallet_zip):
            #             download_atp_cmd='python3 /opt/scripts/oci_api_utils.py download_appdb_atp_wallet {0} {1}'.format(getAppATPId(), atp_wallet_zip)
            #             execute(download_atp_cmd)
            #
            #         unzip_archive(atp_wallet_zip, dest = '/u01/app/oracle/private/wallet/appDB')

            # log("Unpacking archive status [fmiddleware_status={0}, jdk_status={1}, atp_status={2}]".format( str(fmiddleware_status), str(jdk_status), str(atp_status) ))

            # if fmiddleware_status and jdk_status and atp_status:
            #     log('Unpacked all archives successfully before provisioning.')
            # else:
            #     log('ERROR - Could not unpack some artifacts. Check logs for details.')
            #     sys.exit(-1)
        # else:
        #     log('Provisioning completed marker exists, continuing with reboot.')
    except:
        traceback.print_exc()
        sys.exit(-2)

    sys.exit(0)


if __name__ == '__main__':
    main()