#
# Copyright (c) 2020, 2021, 2023 Oracle and/or its affiliates. All rights reserved.
#
"""Restore Weblogic Archives.

Command line arguments:
    Arg1: (optional) - confirm via tar validation.

Returns:
    Returns error code 1 if artifact cant be found or couldn't be restored, 2 if file is found but cannot be copied, 3 for any caught error.
"""

import os
import traceback
import time
import sys
import oci
import sys
sys.path.append('/opt/scripts/')
sys.path.append('/opt/scripts/utils')
from bootstrap import getMode, getVMScriptsPath, getWlsDomainName, log, unzip_archive


class_name="restore_vmscripts.py"


def download_file_from_oss(bucket_name,file_name,store_path, skip_file=False):
    method_name="download_file_from_oss"
    """
         GET Object Storage File from Bucket

         :param bucket_name:
         :param file_name:
         :return: location.
        """
    try:
        principal = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
        object_storage = oci.object_storage.ObjectStorageClient(config={}, signer=principal)
        response = object_storage.get_namespace()
        if response.status == 200:
            namespace = response.data
            wls_archive = object_storage.get_object(namespace, bucket_name=bucket_name, object_name=file_name)
            file_path='{0}/{1}'.format(store_path,file_name)
            with open(file_path,'wb') as f:
                for chunk in wls_archive.data.raw.stream(1024 * 1024, decode_content=False):
                    f.write(chunk)
            msg='<{0}>VM Script {1} downloaded from bucket: {2}'.format(method_name,file_name, bucket_name)
            log(msg)
            return file_path
        else:
            log("ERROR- Response Code from OCI: ",str(response.status))
            raise Exception("Filed to get OSS namespace for bucket {0}. response code [{1}]".format(bucket_name,str(response.status)))
    except oci.exceptions.ServiceError as se:
        if se.status == 404 and skip_file:
            log("<{0}> File {1} not found on this, but has skip flag enabled".format(method_name,file_name))
            return "skipped"
        log("<{0}>Error finding file {1} in OSS".format(method_name,file_name)+str(response.status))
        raise Exception("Filed to get OSS namespace for bucket {0}. response code [{1}]".format(bucket_name,str(response.status)))



def delete_file(archive_on_disk, skip_file=False):
    method_name="delete_file"
    try:
        os.remove(archive_on_disk)
        log("<{0}> File {1} successfully removed".format(method_name,archive_on_disk))
    except FileNotFoundError:
        log("File not found.")
        if skip_file:
            log("<{0}> File {1} skipping file for remove".format(method_name,archive_on_disk))
            return
        else:
            log("ERROR File not found {0} ".format(archive_on_disk))
            sys.exit(1)
    except PermissionError:
        log("ERROR removing file: {0} due to permissions".format(archive_on_disk))
        sys.exit(1)
    except OSError as e:
        log("ERROR removing file: {0} unknown error: {1}".format(archive_on_disk,str(e)))
        sys.exit(1)

if __name__ == '__main__':
    """Usage: restore-vmscripts.py"""
    # Download vmscripts for development.
    # Filename to be restored is replaced directly by terraform template. $${vmscripts_file} to ${vmscripts_file}
    bucket="${bucket_name}"
    temp_store="${temporary_path}"
    mode=getMode()
    try:
        vmscripts_status=True
        if mode is not None and mode.strip().lower() == 'dev':
            archive_on_disk=download_file_from_oss(bucket_name=bucket,file_name="${vmscripts_file}",store_path=temp_store)
        else:
            archive_on_disk=getVMScriptsPath()
        # restore(archive_on_disk,skip_file=False,change_to_dir="/opt/scripts")
        vmscripts_status = unzip_archive(archive_on_disk, '/', '/opt/scripts/databag.py')
        delete_file(archive_on_disk)

    except Exception as ex:
        log("[{0}] [{1}]".format(str(ex), traceback.format_exc()))
        sys.exit(3)



