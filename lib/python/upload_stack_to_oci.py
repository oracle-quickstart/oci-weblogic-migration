"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
"""

import subprocess
import os
import zipfile
import tempfile
import datetime
import shutil
import json

def upload_unzipped_stack_to_oci(stack_zip, bucket_name, namespace, compartment_id, log_file, file_timestamp):
    """
    Uploads the contents of a zipped OCI Resource Manager (ORM) stack to OCI Object Storage.

    Returns:
        int: Exit code
            0 - Success
            1 - Stack zip file not found
            2 - Bucket exists but missing read permission
            3 - Bucket creation failure (missing create policy)
            4 - Upload failure
            5 - Bucket exists but missing write/upload permission
    """

    temp_dir = tempfile.mkdtemp(prefix=f"stack_upload_{file_timestamp}_")

    def log(level, message):
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        line = f"{timestamp}  [{level}] {message}"
        print(line)
        with open(log_file, "a") as lf:
            lf.write(line + "\n")

    def check_or_create_bucket(namespace, bucket_name, compartment_id, log_file):
        """
        Returns (exists: bool, reason: str)
            reason: "missing", "unauthorized", "unknown"
        """
        try:
            subprocess.check_output(
                ["oci", "os", "bucket", "get",
                 "--namespace-name", namespace,
                 "--bucket-name", bucket_name],
                stderr=subprocess.PIPE
            )
            return True, None  # Exists and readable
        except subprocess.CalledProcessError as e:
            stderr_text = e.stderr.decode()
            with open(log_file, "a") as lf:
                lf.write(stderr_text + "\n")
            error_code = ""
            try:
                json_start = stderr_text.find("{")
                if json_start != -1:
                    error_json = json.loads(stderr_text[json_start:])
                    error_code = error_json.get("code", "").lower()
            except Exception:
                pass

            # Unauthorized / no read permission
            if error_code == "notauthorizedornotfound" or "not authorized" in stderr_text.lower():
                return False, "unauthorized"

            # Bucket not found → attempt create
            if error_code == "bucketnotfound":
                try:
                    create_proc = subprocess.run(
                        ["oci", "os", "bucket", "create",
                         "--namespace-name", namespace,
                         "--name", bucket_name,
                         "--compartment-id", compartment_id],
                        stdout=open(log_file, "a"),
                        stderr=subprocess.PIPE
                    )
                    if create_proc.returncode != 0:
                        create_err = create_proc.stderr.decode()
                        if "BucketAlreadyExists" in create_err:
                            return False, "unauthorized"
                        else:
                            return False, "unknown"
                    else:
                        return True, None  # Created successfully
                except subprocess.CalledProcessError:
                    return False, "unknown"

            return False, "unknown"

    # Step 1: Check stack zip
    if not os.path.exists(stack_zip):
        log("error", f"Stack zip file not found: {stack_zip}")
        return 1

    # Step 2: Check or create bucket
    log("info", f"Checking if bucket {bucket_name} exists in namespace {namespace}...")
    exists, reason = check_or_create_bucket(namespace, bucket_name, compartment_id, log_file)

    if not exists:
        if reason == "unauthorized":
            log("warning", f"Access denied to bucket {bucket_name}. Check IAM read policy.")
            return 2
        elif reason == "missing":
            log("warning", f"Bucket {bucket_name} does not exist and cannot be created. Check create policy.")
            return 3
        else:
            log("warning", f"Unexpected error while checking/creating bucket {bucket_name}.")
            return 3
    else:
        log("info", f"Bucket {bucket_name} is ready.")

    # Step 3: Check write/upload permission
    temp_test_file = os.path.join(tempfile.gettempdir(), f"oci_write_test_{file_timestamp}.tmp")
    open(temp_test_file, "w").close()  # zero-byte file
    try:
        subprocess.check_call(
            [
                "oci", "os", "object", "put",
                "--bucket-name", bucket_name,
                "--namespace-name", namespace,
                "--name", f"upload_test_{file_timestamp}.tmp",
                "--file", temp_test_file,
                "--force"
            ],
            stdout=open(log_file, "a"),
            stderr=open(log_file, "a")
        )
        log("info", "Write permission check passed.")
    except subprocess.CalledProcessError:
        log("warning", f"Missing write/upload permission for bucket {bucket_name}.")
        return 5
    finally:
        try:
            os.remove(temp_test_file)
        except Exception:
            pass

    # Step 4: Unzip stack
    log("info", f"Unzipping stack: {stack_zip} to {temp_dir}")
    with zipfile.ZipFile(stack_zip, "r") as zip_ref:
        zip_ref.extractall(temp_dir)

    # Step 5: Upload stack
    log("info", f"Uploading unzipped stack to OCI bucket {bucket_name}...")
    try:
        subprocess.check_call(
            [
                "oci", "os", "object", "bulk-upload",
                "--bucket-name", bucket_name,
                "--namespace-name", namespace,
                "--src-dir", temp_dir,
                "--prefix", f"{file_timestamp}/",
                "--overwrite"
            ],
            stdout=open(log_file, "a"),
            stderr=open(log_file, "a")
        )
        log("info", "Upload completed successfully.")
    except subprocess.CalledProcessError:
        log("warning", f"Failed to upload stack to bucket {bucket_name}. See {log_file} for details.")
        return 4
    # Step 6: Cleanup
    finally:
        try:
            shutil.rmtree(temp_dir)
            log("info", f"Temporary directory {temp_dir} deleted.")
        except Exception as e:
            log("warning", f"Failed to delete temp dir {temp_dir}: {e}")

    return 0
