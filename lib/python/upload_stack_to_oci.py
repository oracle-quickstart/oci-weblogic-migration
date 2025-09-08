"""
Copyright (c) 2025 Oracle and/or its affiliates.
Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.
"""

import subprocess
import os
import zipfile
import tempfile
import datetime
import shutil

def upload_unzipped_stack_to_oci(stack_zip, bucket_name, namespace, compartment_id, log_file, file_timestamp):
    """
    Uploads the contents of a zipped OCI Resource Manager (ORM) stack to Oracle Cloud Infrastructure (OCI) Object Storage.

    This function:
    - Checks if the provided zip file exists.
    - Verifies whether the specified OCI bucket exists; creates it if it doesn't.
    - Extracts the zip file into a temporary directory.
    - Uploads the extracted contents to OCI using the `oci os object bulk-upload` command.
    - Cleans up the temporary directory after upload.

    Args:
        stack_zip (str): Path to the zip file containing the ORM stack.
        bucket_name (str): Name of the OCI Object Storage bucket.
        namespace (str): OCI tenancy namespace.
        compartment_id (str): OCID of the compartment where the bucket resides.
        log_file (str): Path to a log file for storing operation output and errors.
        file_timestamp (str): Unique timestamp string used to create a folder prefix in the bucket.

    Usage:
    Intended to be invoked from a shell wrapper via `python3 -c` or imported as a module.

    Returns:
        int: Exit code representing the result of the operation:
            0 - Success
            1 - Stack zip file not found
            2 - Bucket check failed (e.g., namespace or policy issue)
            3 - Bucket creation or upload failure
    """

    temp_dir = tempfile.mkdtemp(prefix=f"stack_upload_{file_timestamp}_")

    def log(level, message):
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        line = f"{timestamp}  [{level}] {message}"
        print(line)
        with open(log_file, "a") as lf:
            lf.write(line + "\n")

    # Step 1: Check if stack zip exists
    if not os.path.exists(stack_zip):
        log("error", f"Stack zip file not found: {stack_zip}")
        return 1

    log("info", f"Checking if bucket {bucket_name} exists in namespace {namespace}...")

    # Step 2: Check if the bucket exists
    try:
        bucket_exists = subprocess.check_output(
            [
                "oci", "os", "bucket", "list",
                "--namespace-name", namespace,
                "--compartment-id", compartment_id,
                "--query", f"data[?name=='{bucket_name}'] | length(@)",
                "--raw-output"
            ],
            stderr=subprocess.PIPE
        ).decode().strip()
    except subprocess.CalledProcessError as e:
        with open(log_file, "a") as lf:
            lf.write(e.stderr.decode() + "\n")
        log("warning", f"Failed to check if bucket {bucket_name} exists in namespace {namespace}.")
        return 2

    # Step 3: Create bucket if missing
    if bucket_exists == "0":
        log("info", f"Bucket {bucket_name} not found in namespace {namespace}. Creating...")
        try:
            subprocess.check_call(
                [
                    "oci", "os", "bucket", "create",
                    "--namespace-name", namespace,
                    "--name", bucket_name,
                    "--compartment-id", compartment_id
                ],
                stdout=open(log_file, "a"),
                stderr=open(log_file, "a")
            )
            log("info", f"Bucket {bucket_name} created successfully.")
        except subprocess.CalledProcessError as e:
            log("warning", f"Failed to create bucket {bucket_name}. See {log_file} for details.")
            return 3
    else:
        log("info", f"Bucket {bucket_name} already exists.")

    # Step 4: Unzip stack
    log("info", f"Unzipping stack: {stack_zip} to {temp_dir}")
    with zipfile.ZipFile(stack_zip, "r") as zip_ref:
        zip_ref.extractall(temp_dir)

    # Step 5: Upload stack
    log("info", "Uploading unzipped stack to OCI bucket {bucket_name}...")
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
    finally:
        # Cleanup
        try:
            shutil.rmtree(temp_dir)
            log("info", f"Temporary directory {temp_dir} deleted.")
        except Exception as e:
            log("warning", f"Failed to delete temp dir {temp_dir}: {e}")
