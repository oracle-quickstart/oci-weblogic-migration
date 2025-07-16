#
# Copyright (c) 2025 Oracle and/or its affiliates. All rights reserved.
#
# Currently this file is not being used but is retained in case we need the wls-oci vmscripts.
"""Restores wls-oci vmscripts.

Command line arguments:
    Arg1: (optional) - confirm via tar validation.

Returns:
    Returns error code 1 if artifact cant be found or couldn't be restored, 2 if file is found but cannot be copied, 3 for any caught error.
"""

import os
import traceback
import oci
import sys
from restore_archives import get_attribute, execute

class_name="restore_vmscripts.py"

def get_mode():
    return get_attribute('mode')

def get_vm_scripts_path():
    return get_attribute('vmscripts_path')

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

def log(msg):
    print(msg)

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
            raise Exception("Failed to get OSS namespace for bucket {0}. response code [{1}]".format(bucket_name,str(response.status)))
    except oci.exceptions.ServiceError as se:
        if se.status == 404 and skip_file:
            log("<{0}> File {1} not found on this, but has skip flag enabled".format(method_name,file_name))
            return "skipped"
        log("<{0}>Error finding file {1} in OSS".format(method_name,file_name)+str(response.status))
        raise Exception("Failed to get OSS namespace for bucket {0}. response code [{1}]".format(bucket_name,str(response.status)))



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
    mode=get_mode()
    try:
        vmscripts_status=True
        if mode is not None and mode.strip().lower() == 'dev':
            log("WARNING - Running Stack in Development Mode")
            archive_on_disk=download_file_from_oss(bucket_name=bucket,file_name="${vmscripts_file}",store_path=temp_store)
            vmscripts_status = unzip_archive(archive_on_disk, '/', '/opt/scripts/databag.py')
            delete_file(archive_on_disk)
        elif mode is not None and mode.strip().lower() == 'prod':
            archive_on_disk=get_vm_scripts_path()
            log("INFO - Prod mode. Using Archive On Disk {0} ".format(archive_on_disk))
            vmscripts_status = unzip_archive(archive_on_disk, '/', '/opt/scripts/databag.py')
        else:
            log("ERROR - Invalid Stack Mode value in metadata {0} ".format(mode))
            vmscripts_status=False
        log("INFO - <Return> {0}".format(vmscripts_status))
    except Exception as ex:
        log("[{0}] [{1}]".format(str(ex), traceback.format_exc()))
        sys.exit(3)



