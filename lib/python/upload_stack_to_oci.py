# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
###########################################################################################
# Description          : Script to upload ORM stack to OCI Object Storage Bucket
###########################################################################################

import subprocess
import os
import zipfile
import tempfile
import datetime
import shutil

def upload_unzipped_stack_to_oci(stack_zip, bucket_name, namespace, compartment_id, log_file, file_timestamp):
    temp_dir = tempfile.mkdtemp(prefix=f"stack_upload_{file_timestamp}_")

    def log(level, message):
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        line = f"{timestamp}  [{level}] {message}"
        print(line)
        with open(log_file, "a") as lf:
            lf.write(line + "\n")

    if not os.path.isfile(stack_zip):
        log("error", f"Stack zip file not found: {stack_zip}")
        return 1

    log("info", f"Checking if bucket {bucket_name} exists in namespace {namespace}...")

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
        log("warning", f"Bucket check failed for {bucket_name} in {namespace}. Skipping upload.")
        return 2   # Special code for namespace/policy error

    if bucket_exists == "0":
        log("info", f"Bucket {bucket_name} not found. Creating...")
        subprocess.run(
            [
                "oci", "os", "bucket", "create",
                "--namespace-name", namespace,
                "--name", bucket_name,
                "--compartment-id", compartment_id
            ],
            stdout=open(log_file, "a"),
            stderr=open(log_file, "a")
        )
        log("info", f"Bucket {bucket_name} created.")
    else:
        log("info", f"Bucket {bucket_name} already exists.")

    log("info", f"Unzipping stack: {stack_zip} to {temp_dir}")
    with zipfile.ZipFile(stack_zip, "r") as zip_ref:
        zip_ref.extractall(temp_dir)

    log("info", "Uploading unzipped stack to OCI bucket...")
    try:
        subprocess.run(
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
        try:
            shutil.rmtree(temp_dir)
            log("info", f"Temporary directory {temp_dir} deleted.")
        except os.exception as e:
            log("warning", f"Failed to delete temp dir {temp_dir}: {e}")

    except subprocess.CalledProcessError as e:
        with open(log_file, "a") as lf:
            lf.write(e.stderr.decode() + "\n")
        log("warning", f"Bucket check failed for {bucket_name} in {namespace}. Skipping upload.")
        return 3  # code for namespace/policy error