#
# Copyright (c) 2024, 2025 Oracle and/or its affiliates. All rights reserved.
#
"""Restore Weblogic Archives.

Command line arguments:
    Arg1: (optional) - confirm via tar validation.

Returns:
    Returns error code 1 if artifact cant be found or couldn't be restored, 2 if file is found but cannot be copied, 3 for any caught error.
"""
import oci
import os
import sys
import traceback
import subprocess
import urllib.request, urllib.error, urllib.parse

class_name="restore_archives.py"

def log(msg):
    print(msg)

# Get metadata attribute.
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
        return result.decode("utf-8")
    except Exception as ex:
        print(f"Error: {ex}")
        pass

    return default

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
            msg='<{0}>WebLogic Archive {1} downloaded from bucket: {2}'.format(method_name,file_name, bucket_name)
            log(msg)
            print(msg)
            return file_path
        else:
            log("ERROR: Response Code from OCI: {0}".format(str(response.status)))
            raise Exception("Failed to get OSS namespace for bucket {0}. response code [{1}]".format(bucket_name,str(response.status)))
    except oci.exceptions.ServiceError as se:
        if se.status == 404 and skip_file:
            log("<{0}> File {1} not found on this, but has skip flag enabled".format(method_name,file_name))
            return "skipped"
        log("<{0}>Error finding file {1} in OSS".format(method_name,file_name)+str(response.status))
        raise Exception("Failed to get OSS namespace for bucket {0}. response code [{1}]".format(bucket_name,str(response.status)))


def restore(archive_file,skip_file=False, change_to_dir="/"):
    method_name="restore"
    print("About to restore {0}".format(archive_file))
    try:
        # First see if the file is present with ls command.
        list_file_command = 'ls {0} 2>&1'.format(archive_file)
        log('<{0}> Running Command: {1}'.format(method_name,list_file_command))
        results, status = execute(list_file_command)
        log('<{0}> status {1}'.format(method_name,str(status)))
        if status != 0 and skip_file:
            log("<{0}> File {1} not found on this, but has skip flag enabled".format(method_name,archive_file))
            return 0
        if status !=0 and not skip_file:
            log('Error: {0}' .format(archive_file))
            sys.exit(1)

        # If the file is found, attempt to untar it. Turn on output messages, because earlier ls confirmed file presence.
        untar_file_command='tar xzfp {0} -C {1} 2>&1'.format(archive_file, change_to_dir)
        log('Executing {0}'.format(untar_file_command))
        results, status = execute(untar_file_command)
        log('<{0}> results {1}'.format(method_name,str(results)))
        log('<{0}> status {1}'.format(method_name,str(status)))
        if status != 0:
            log('Error: {0}'.format(results))
            sys.exit(2)
        return status
    except Exception as ex:
        log("Error: [{0}] [{1}]".format(str(ex), traceback.format_exc()))
        sys.exit(3)


def delete_file(archive_on_disk, skip_file=False):
    method_name="delete_file"
    try:
        os.remove(archive_on_disk)
        log("<{0}> File {1} successfully removed".format(method_name,archive_on_disk))
    except FileNotFoundError:
        print("File not found.")
        if skip_file:
            log("<{0}> File {1} skipping file for remove".format(method_name,archive_on_disk))
            return
        else:
            log("ERROR File not found {0} ".format(archive_on_disk))
            sys.exit(1)
    except PermissionError:
        print("You don't have permission to delete this file.")
        log("ERROR removing file: {0} due to permissions".format(archive_on_disk))
        sys.exit(1)
    except OSError as e:
        print(f"Error deleting file: {e.strerror}")
        log("ERROR removing file: {0} unknown error: {1}".format(archive_on_disk,str(e)))
        sys.exit(1)

if __name__ == '__main__':
    """Usage: restore-archives.py"""
    # Restores all WLS Archives from Terraform generated template
    bucket="${bucket_name}"
    temp_store="${temporary_path}"
    try:
        archive_on_disk=download_file_from_oss(bucket_name=bucket,file_name="${middleware_archive}",store_path=temp_store)
        restore(archive_on_disk,skip_file=False,change_to_dir="${restore_path}")
        delete_file(archive_on_disk)
        print("processing next wls archive")
        archive_on_disk=download_file_from_oss(bucket_name=bucket,file_name="${jdk_archive}",store_path=temp_store)
        restore(archive_on_disk,skip_file=False,change_to_dir="${restore_path}")
        delete_file(archive_on_disk)
        print("processing next wls archive")
        archive_on_disk=download_file_from_oss(bucket_name=bucket,file_name="${domain_archive}",store_path=temp_store)
        restore(archive_on_disk,skip_file=False,change_to_dir="${restore_path}")
        delete_file(archive_on_disk)
        print("processing next wls archive")
        archive_on_disk=download_file_from_oss(bucket_name=bucket,file_name="${custom_archive}",store_path=temp_store,skip_file=True)
        restore(archive_on_disk,skip_file=True,change_to_dir="${restore_path}")
        delete_file(archive_on_disk,skip_file=True)
    except Exception as ex:
        log("Error: [{0}] [{1}]".format(str(ex), traceback.format_exc()))
        sys.exit(3)



