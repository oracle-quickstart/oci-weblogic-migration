"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
"""

import subprocess
import os
import tempfile
import datetime
import sys
import json

def upload_stack_zip_to_oci(stack_zip, bucket_name, namespace, compartment_id, log_file, file_timestamp):
    """
    Uploads a stack.zip file (or any specified filename) to OCI Object Storage and generates a PAR URL (valid for 6 months).

    Returns:
        tuple (exit_code, par_url)
            exit_code:
                0 - Success
                1 - Stack zip file not found
                2 - Bucket exists but missing read permission
                3 - Bucket creation failure (missing create policy, or bucket exists in another compartment)
                4 - Upload failure
                5 - Bucket exists but missing write/upload permission
            par_url: Pre-Authenticated Request URL if success, else None
    """

    def log(level, message):
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        line = f"{timestamp}  [{level}] {message}"
        with open(log_file, "a") as lf:
            lf.write(line + "\n")

    def check_or_create_bucket(namespace, bucket_name, compartment_id):
        """
        Returns (exists: bool, reason: str, actual_compartment: str)
        reason: "unauthorized", "wrong_compartment", "missing", "unknown"
        """
        try:
            result = subprocess.run(
                ["oci", "os", "bucket", "get",
                 "--namespace-name", namespace,
                 "--bucket-name", bucket_name],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            if result.returncode == 0:
                bucket_json = json.loads(result.stdout.decode())
                bucket_compartment = bucket_json["data"]["compartment-id"]
                if bucket_compartment != compartment_id:
                    return False, "wrong_compartment", bucket_compartment
                return True, "ok", bucket_compartment
            else:
                stderr_text = result.stderr.decode()
                error_code = ""
                try:
                    json_start = stderr_text.find("{")
                    if json_start != -1:
                        error_json = json.loads(stderr_text[json_start:])
                        error_code = error_json.get("code", "").lower()
                except Exception:
                    pass

                if error_code == "bucketnotfound":
                    create_proc = subprocess.run(
                        ["oci", "os", "bucket", "create",
                         "--namespace-name", namespace,
                         "--name", bucket_name,
                         "--compartment-id", compartment_id],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE
                    )
                    if create_proc.returncode == 0:
                        return True, "ok", compartment_id
                    else:
                        create_err = create_proc.stderr.decode()
                        if "BucketAlreadyExists" in create_err:
                            return False, "wrong_compartment", None
                        else:
                            return False, "unknown", None

                elif error_code == "notauthorizedornotfound" or "not authorized" in stderr_text.lower():
                    return False, "unauthorized", None
                else:
                    return False, "unknown", None

        except Exception as e:
            log("warning", f"Exception while checking/creating bucket: {e}")
            return False, "unknown", None

    # Step 1: Check stack zip
    if not os.path.exists(stack_zip):
        log("error", f"Stack file not found: {stack_zip}")
        return 1, None

    stack_filename = os.path.basename(stack_zip)

    # Step 2: Check or create bucket
    log("info", f"Checking if bucket {bucket_name} exists in namespace {namespace}...")
    exists, reason, actual_compartment = check_or_create_bucket(namespace, bucket_name, compartment_id)

    if not exists:
        if reason == "unauthorized":
            log("warning", f"Access denied to bucket {bucket_name}. Check IAM read policy.")
            return 2, None
        elif reason == "wrong_compartment":
            log("error", (f"Bucket {bucket_name} exists in a different compartment.\n"
                          f"Actual: {actual_compartment}, Provided: {compartment_id}"))
            return 3, None
        else:
            log("warning", f"Unexpected error while checking/creating bucket {bucket_name}.")
            return 3, None
    else:
        log("info", f"Bucket {bucket_name} is ready in compartment {actual_compartment}.")

    # Step 3: Check write/upload permission
    temp_test_file = os.path.join(tempfile.gettempdir(), f"oci_write_test_{file_timestamp}.tmp")
    open(temp_test_file, "w").close()
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
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        log("info", "Write permission check passed.")
    except subprocess.CalledProcessError:
        log("warning", f"Missing write/upload permission for bucket {bucket_name}.")
        return 5, None
    finally:
        try:
            os.remove(temp_test_file)
        except Exception:
            pass

    # Step 4: Upload stack file
    log("info", f"Uploading {stack_filename} to OCI bucket {bucket_name}...")
    try:
        subprocess.check_call(
            [
                "oci", "os", "object", "put",
                "--bucket-name", bucket_name,
                "--namespace-name", namespace,
                "--name", stack_filename,
                "--file", stack_zip,
                "--force"
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        log("info", f"{stack_filename} uploaded successfully to bucket {bucket_name}.")
    except subprocess.CalledProcessError:
        log("warning", f"Failed to upload {stack_filename} to bucket {bucket_name}.")
        return 4, None

    # Step 5: Create PAR URL valid for 6 months
    log("info", f"Creating Pre-Authenticated Request (PAR) URL for {stack_filename} valid for 6 months...")
    try:
        par_proc = subprocess.run(
            [
                "oci", "os", "preauth-request", "create",
                "--bucket-name", bucket_name,
                "--namespace-name", namespace,
                "--name", f"{stack_filename}-par-{file_timestamp}",
                "--access-type", "ObjectRead",
                "--time-expires", (datetime.datetime.utcnow() + datetime.timedelta(days=180)).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "--object-name", stack_filename
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        if par_proc.returncode != 0:
            log("warning", f"Failed to create PAR URL for {stack_filename}.")
            return 4, None

        par_json = json.loads(par_proc.stdout.decode())
        par_url = par_json["data"]["full-path"]
        log("info", f"PAR URL created (valid 6 months): {par_url}")

        # Return JSON to shell
        print(json.dumps({'code': 0, 'par_url': par_url}))
        sys.exit(0)

    except Exception as e:
        log("warning", f"Exception while creating PAR URL: {e}")
        return 4, None


# If run directly for testing
if __name__ == "__main__":
    import sys
    code, par_url = upload_stack_zip_to_oci(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
    print(json.dumps({'code': code, 'par_url': par_url}))
    sys.exit(code)
