# OCI WebLogic Migration Tool

The OCI WebLogic Migration Tool helps you prepare an existing **Oracle WebLogic Server** environment for migration to **Oracle Cloud Infrastructure (OCI)**.

It is intended for users performing a **lift-and-shift style migration** from a Linux-based WebLogic environment. The tool does not perform a one-click migration by itself. Instead, it helps you collect, generate, and package the information and artifacts needed for migration and deployment in OCI.

## Who should use this tool

Use this tool if you need to migrate an existing WebLogic domain to OCI and want help with:

- discovering the current WebLogic domain configuration
- discovering the underlying infrastructure used by that domain
- discovering datasources and generating OCI Resource Manager inputs
- building an OCI Resource Manager stack bundle
- archiving WebLogic, Java, and domain assets
- optionally uploading generated artifacts to OCI Object Storage

## What the tool produces

After a successful run, the tool can generate:

- a WebLogic discovery JSON file
- an infrastructure discovery JSON file
- datasource-related Terraform and schema files under `oci/generated/`
- an OCI Resource Manager stack ZIP under `oci/stack/`
- migration archives under `out/`
- run status and output tracking in `logs/migration_data.json`
- optionally, an OCI Object Storage upload and PAR URL for the generated stack ZIP

## How the migration workflow works

At a high level, the workflow is:

1. Install dependencies.
2. Validate prerequisites on the source Linux host.
3. Discover the WebLogic domain.
4. Discover the infrastructure referenced by that domain.
5. Discover datasources and generate OCI-related files.
6. Build an OCI Resource Manager stack ZIP.
7. Archive the WebLogic environment for transfer.
8. Optionally upload generated artifacts to OCI Object Storage.

For most users, the main entry point is:

```bash
bash bin/migration_script.sh
```

## Supported execution environment

The prerequisite validation script expects the tool to run in a Linux environment with access to the source WebLogic installation.

Minimum expectations enforced by `bin/check_pre-reqs.sh` include:

- **Operating system:** Oracle Linux 8+ or Red Hat Enterprise Linux 8+
- **Run as:** a **non-root** user
- **Memory:** at least **8 GiB RAM**
- **CPU:** at least **1 vCPU**
- **Internet access:** outbound access to Oracle and OCI endpoints

> Run the tool on a Linux host that has access to the source WebLogic domain, Oracle Home, and Java Home. If you want automatic OCI uploads, that host must also have OCI CLI access configured.

## Before you begin

Gather the following information before editing the configuration file.

### Source environment information

- Linux host where you will run the tool
- WebLogic domain path
- Oracle Home path
- Java Home path
- operating system user with read access to the WebLogic, Oracle, and Java directories
- SSH authentication material required by the workflow

### OCI information

If you want the tool to upload artifacts automatically (`skip_transfer=false`), also gather:

- OCI Object Storage bucket name
- OCI compartment OCID
- tenancy namespace
- OCI CLI configuration on the host

## Repository layout

- `bin/` - shell entry points for installation, validation, discovery, archiving, and stack generation
- `config/` - user configuration, including `on-prem.env`
- `lib/python/` - Python helpers used by discovery, metadata handling, archiving, and OCI uploads
- `oci/rm/` - Terraform / OCI Resource Manager templates
- `oci/generated/` - generated Terraform fragments and schema files
- `oci/stack/` - generated stack ZIP files
- `logs/` - workflow logs and migration metadata
- `out/` - generated discovery output and archives

## Configuration

Edit the main configuration file before running the workflow:

```text
config/on-prem.env
```

This file controls how the tool discovers the source environment, authenticates over SSH, and optionally uploads artifacts to OCI.

### Required values

These values are always required:

```properties
ssh_user=
domain_home=
oracle_home=
java_home=
skip_transfer=false
```

### SSH authentication

You must provide **one** SSH authentication method:

Use a private key:

```properties
ssh_private_key_file=
```

Or use a password file:

```properties
ssh_password_file=
```

If your SSH private key is passphrase protected, also set:

```properties
ssh_private_key_pass_file=
```

### OCI upload values

If `skip_transfer=false`, these values are also required:

```properties
bucket_name=
compartment_ocid=
tenancy_namespace=
```

### Example `config/on-prem.env`

```properties
ssh_user=oracle
ssh_private_key_file=/home/oracle/.ssh/id_rsa
ssh_private_key_pass_file=
ssh_password_file=

domain_home=/u01/domains/base_domain
oracle_home=/u01/app/oracle/middleware
java_home=/usr/java/jdk-11

skip_transfer=false
bucket_name=my-wls-migration-bucket
compartment_ocid=ocid1.compartment.oc1..exampleuniqueID
tenancy_namespace=mytenancynamespace
```

## Understanding `skip_transfer`

The `skip_transfer` setting changes what the workflow expects and what it does after creating artifacts.

### When `skip_transfer=false`

- OCI upload settings are required in `config/on-prem.env`
- the tool uploads the generated stack ZIP to OCI Object Storage
- the tool can generate a PAR URL for the uploaded stack ZIP
- OCI CLI must be installed and configured on the host

### When `skip_transfer=true`

- OCI upload settings are not required
- automatic uploads are skipped
- you are responsible for manually transferring the required archives and artifacts to OCI Object Storage later

## Prerequisites

Before running the full workflow, make sure the host has:

- Python available on the path
- OCI Python client library
- `curl`
- `zip` and `unzip`
- `ssh` and `scp`
- `sshpass` if you use password-based SSH authentication
- OCI CLI configured if `skip_transfer=false`

The repository includes helper scripts for setup and validation:

- `bin/install_dependencies.sh`
- `bin/check_pre-reqs.sh`

## Quick start

For most users, this is the recommended path.

### 1. Configure the tool

Update:

```text
config/on-prem.env
```

### 2. Install dependencies

```bash
bash bin/install_dependencies.sh
```

### 3. Validate prerequisites

```bash
bash bin/check_pre-reqs.sh
```

This verifies:

- OS compatibility
- CPU and memory
- internet connectivity
- correctness of `config/on-prem.env`
- required package availability
- OCI CLI configuration when uploads are enabled

### 4. Run the end-to-end migration preparation workflow

```bash
bash bin/migration_script.sh
```

This script orchestrates the main workflow and records progress in:

- `logs/migration_script.log`
- `logs/migration_data.json`

## Step-by-step workflow

If you prefer to run the process in stages instead of using the consolidated script, use the following sequence.

### 1. Discover the WebLogic domain

```bash
bash bin/owm.sh wls
```

Output:

- creates a WebLogic inventory JSON such as `out/Discovered_<timestamp>.json`
- stores its path in `logs/migration_data.json` under `wls_json`

### 2. Discover infrastructure

```bash
bash bin/owm.sh infra <path-to-wls-json>
```

Example:

```bash
bash bin/owm.sh infra out/Discovered_202601011230.json
```

Output:

- creates an infrastructure JSON such as `out/infra_output_<timestamp>.json`
- stores its path in `logs/migration_data.json` under `infra_json`

### 3. Discover datasources

```bash
bash bin/owm.sh ds <path-to-infra-json>
```

Output:

- generates datasource-related Terraform and schema files in `oci/generated/`

### 4. Build the OCI Resource Manager stack

```bash
bash bin/owm.sh orm <path-to-infra-json>
```

Output:

- creates a stack ZIP in `oci/stack/`
- stores its path in `logs/migration_data.json` under `stack_file`

### 5. Archive the WebLogic environment

```bash
bash bin/owm.sh archive <path-to-infra-json>
```

Output:

- creates migration archives for the domain and related assets in `out/`

### 6. Optional OCI upload behavior

If `skip_transfer=false`, `bin/migration_script.sh` uploads the generated stack ZIP to OCI Object Storage automatically.

If `skip_transfer=true`, uploads are skipped and you must manually transfer the generated archives and related artifacts to OCI before any downstream restore or deployment process that depends on them.

## Main commands

### Full workflow

```bash
bash bin/migration_script.sh
```

### Individual commands

```bash
bash bin/owm.sh wls
bash bin/owm.sh infra <wls-json>
bash bin/owm.sh ds <infra-json>
bash bin/owm.sh orm <infra-json>
bash bin/owm.sh archive <infra-json>
```

### Help

```bash
bash bin/owm.sh --help
bash bin/install_dependencies.sh --help
```

## Outputs and logs

During a successful run, you should expect outputs similar to the following.

### Generated files

- WebLogic discovery JSON in `out/Discovered_<timestamp>.json`
- infrastructure discovery JSON in `out/infra_output_<timestamp>.json`
- datasource-generated Terraform and schema files in `oci/generated/`
- OCI Resource Manager stack ZIP in `oci/stack/`
- migration archives in `out/`

### Logs

- `logs/migration_script.log` - overall workflow log
- `logs/owm.log` - command-level log output

### Metadata

- `logs/migration_data.json` - tracks generated files and workflow step status

Typical keys include:

- `install_dependencies`
- `prerequisites_check`
- `wls_discover`
- `infra_discover`
- `discover_datasources`
- `build_oci_orm`
- `stack_file`
- `upload_stack_to_oci`
- `archive_weblogic_domain`
- `wls_json`
- `infra_json`
- `PAR URL`

If stack upload succeeds, the tool can also generate a **Pre-Authenticated Request (PAR) URL** for the stack ZIP.

## Rerun behavior

The workflow records status in `logs/migration_data.json`.

If a step has already completed successfully, rerunning `bin/migration_script.sh` can skip that step instead of repeating it. This helps resume the workflow after fixing a problem.

## Troubleshooting

### Prerequisite check fails

Run:

```bash
bash bin/check_pre-reqs.sh
```

Fix all reported issues before running the migration workflow again.

Common causes include:

- missing values in `config/on-prem.env`
- invalid paths for `domain_home`, `oracle_home`, or `java_home`
- missing SSH credential files
- OCI CLI not installed or not configured
- missing internet connectivity

### Migration stops in the middle

Review:

- `logs/migration_script.log`
- `logs/owm.log`
- `logs/migration_data.json`

These files show which step failed and what outputs were already generated.

### Metadata file is invalid or corrupted

If `logs/migration_data.json` becomes invalid, the safest recovery is:

1. review the logs to understand the failure
2. remove `logs/migration_data.json`
3. remove stale generated content from `out/` if appropriate
4. rerun `bash bin/migration_script.sh`

## Important notes

- This tool prepares migration artifacts and OCI deployment inputs. It is not a single command that fully moves and restores a WebLogic environment in OCI.
- Review generated stack files and Terraform inputs before deploying them in OCI.
- If uploads are skipped, make sure all required archives are manually uploaded to OCI Object Storage before downstream restore or provisioning steps.

## Contributing and security

For contribution guidelines, see `CONTRIBUTING.md`.

For security reporting guidance, see `SECURITY.md`.

## License

Licensed under the Universal Permissive License (UPL), Version 1.0. See `LICENSE.txt`.