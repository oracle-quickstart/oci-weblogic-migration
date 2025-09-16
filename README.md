Purpose
-------
The **OCI WebLogic Migration Tool** enables lift-and-shift migration of single or multi-node WebLogic domains from on-premises environments to **Oracle Cloud Infrastructure (OCI)**, optionally fronted by a load balancer.  

Key features of the tool:

- The tool **introspects the existing WebLogic Domain** to discover domain configuration, managed servers, clusters, applications, and resources.  
- Based on this discovery, it generates a **tailored Resource Manager stack** that leverages OCI Resource Manager to securely provision and configure:  
  - **OCI Networking resources** (VCN, subnets, gateways, route tables, and security lists)  
  - **Compute Instances** to host the discovered WebLogic domain  
  - Optional **load balancers** for distributing traffic across WebLogic managed servers  
- The tool updates **JDBC datasource configuration files** in the domain so that WebLogic servers in OCI can connect to target databases.  

> **Important:**  
> It is the **user’s responsibility** to complete the database migration prior to applying the stack.


Requirements
----------------------------

*On-Premise Requirements*

To deploy the software, ensure the following prerequisites are met:

    Oracle Linux compatibility: The operating system release should be within the supported range.

    File system permissions: WebLogic Migration Tool is designed to be installed directly on to the AdminServer Host. An Operating System user with read and write permissions on WebLogic Domain's , Oracle Middleware and Java Home is require to perform tasks such us unzip, tar.

    Internet Connection: WebLogic Migration Tool requires access to github.com repositories to download two required libraries - Weblogic Deployment Tool - to discover the source WebLogic environment. Alternatively, specific releases can be manually download and placed in $toolHome/deps/wdt. 

    Network configuration: AdminServer Host must have an established SSH authentication system in place, connecting the AdminServer and all the Weblogic Managed server Linux hosts seamlessly.

    Storage Space:  Admin Server disk space to store 3 times the space used by Oracle Middleware and Oracle Domain home combined.

    Oracle Cloud Infrastructure CLI: The process of migrating an source on-premise WebLogic Domain involves compressing different directories and uploading them to an Oracle Cloud Object Storage Bucket. Current release uploads files using OCI cli. This requires the user to install and configure the OCI CLI on the admin server host of the on-premise domain.
    Details on how to install and configured can be found at https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm


*Oracle Cloud Requirements*

    Oracle Cloud Account (Tenancy) :  Resources discovered on-premise will be recreated under an OCI Tenancy.  

    OCI Compartment:  Oracle Cloud facilitates the organzation of resources using a logical separation called compartments.  A compartment is requred to group all the resources created by Oracle WebLogic Migration Tool.

    OCI Resource Manager:  Oracle Cloud Account with permissions to create, plan and apply Stacks.

    OCI Permissions:  Oracle CLoud user must have enough permissions to create, destroy, manage Virtual Cloud Network, Compute Instances, Block Storage, LoadBalancers, Private Resource Manager Endpoints.    


Installing Weblogic Migration Tool
----------------------------------------
* Initiate a Secure Shell (SSH) connection to the AdminServer Linux Host, utilizing a user account with read and write file system permissions. This step enables secure remote access and interaction with the server.
* Download the most recent release from  https://github.com/oracle-quickstart/oci-weblogic-migration/releases
* Unzip the installer to a folder where the user has read and write permissions.
* Folder will be referenced as $toolHome.

Alternately, clone the repository with the commands:

```bash
git clone https://github.com/oracle-quickstart/oci-weblogic-migration
cd oci-weblogic-migration
ls
```
Example output:

```bash
$ git clone https://github.com/oracle-quickstart/oci-weblogic-migration
Cloning into 'oci-weblogic-migration'...
Username for 'https://github.com': mahuwa-barman
Password for 'https://mahuwa-barman@github.com': 
remote: Enumerating objects: 4391, done.
remote: Counting objects: 100% (962/962), done.
remote: Compressing objects: 100% (333/333), done.
remote: Total 4391 (delta 819), reused 629 (delta 629), pack-reused 3429 (from 2)
Receiving objects: 100% (4391/4391), 9.01 MiB | 40.84 MiB/s, done.
Resolving deltas: 100% (2822/2822), done.

ls -lrth oci-weblogic-migration
total 40K
-rw-rw-r--. 1 oracle oracle 1.9K Sep 10 08:18 LICENSE
-rw-rw-r--. 1 oracle oracle  18K Sep 10 08:19 README.md
drwxrwxr-x. 2 oracle oracle   41 Sep 10 08:19 config
drwxrwxr-x. 4 oracle oracle   37 Sep 10 08:19 lib
drwxrwxr-x. 6 oracle oracle   58 Sep 10 08:19 oci
drwxrwxr-x. 3 oracle oracle   17 Sep 10 08:19 wdtconfig
drwxrwxr-x. 4 oracle oracle   28 Sep 10 08:19 deps
drwxrwxr-x. 2 oracle oracle 4.0K Sep 11 08:21 bin
drwxrwxr-x. 3 oracle oracle  113 Sep 11 14:48 out
drwxrwxr-x. 2 oracle oracle 4.0K Sep 11 18:02 logs
```

WebLogic Migration Script
-----------------------
This repository contains a consolidated script migration_script.sh that automates the complete migration of an on-premise WebLogic domain to Oracle Cloud Infrastructure (OCI).
The script combines all required tasks into a single workflow:

1. Install dependencies
2. Discover WebLogic domain and infrastructure
3. Discover datasources
4. Generate OCI Resource Manager stack
5. Upload stack to OCI Object Storage Bucket
6. Archive WebLogic domain
7. Upload archives to OCI Object Storage Bucket


Usage
----------------------------------------
### Step 1.  Declare WebLogic source domain details in $toolHome/config/on-prem.env

```bash
######################################################################
# ssh_user:  An Operating System user with read and write permissions
#            on WebLogic Domain, Oracle Middleware and Java Home.
# Example oracle
######################################################################
ssh_user=

######################################################################
# CLEAR VALUE (leave blank) if ssh_password_file is set.
# ssh_private_key_file:  The file name of a file that contains the user’s private key
#                        to use when authenticating with a public/private key pair.
# Example /home/oracle/.ssh/id_rsa
######################################################################
ssh_private_key_file=

######################################################################
# CLEAR VALUE (leave blank) if ssh_private_key_file is not passphrase protected.
# ssh_private_key_pass_file: Path to file containing passphrase for private key
#                            (required only if your private key is passphrase protected).
######################################################################
ssh_private_key_pass_file=

######################################################################
# CLEAR VALUE (leave blank) if ssh_private_key_file is set.
# ssh_password_file:  The file name of a file that contains the password string for the
#                     user’s password to use when authenticating with user name and password.
######################################################################
ssh_password_file=

######################################################################
# domain_home:  Weblogic Domain's path. Domain to migrate to OCI.
# oracle_home:  Home directory of the Oracle WebLogic installation.
#               Set to ORACLE_HOME in local Linux Server.
######################################################################
domain_home=
oracle_home=

######################################################################
# CLEAR VALUE (leave blank) if Weblogic Deployment Type is not Node Manager per Machine.
# node_manager_home: Path where the Node Manager is installed and configured.
######################################################################
node_manager_home=

######################################################################
# skip_transfer:  Defaults to false.
#   - false: Archives will be transferred to OCI Object Storage.
#            bucket_name, compartment_ocid, and tenancy_namespace must be set.
#   - true : Archive transfer is skipped. The below OCI storage parameters are not required.
######################################################################
skip_transfer=false

######################################################################
# The following values are required ONLY if skip_transfer=false
# bucket_name:       Name of the OCI Object Storage Bucket where archives will be uploaded.
# compartment_ocid:  The compartment where the OCI Object Storage bucket exists(in case bucket
#                    is pre-existing) or to be created(in case bucket is not pre-existing).
# tenancy_namespace: Namespace of the tenancy.
######################################################################
bucket_name=
compartment_ocid=
tenancy_namespace=  
```

### Step 2. Run the migration script from the $toolHome/bin directory.
 
```bash
$ bash migration_script.sh
```
The script is idempotent:
If a step has already completed successfully in a previous run, it will be skipped automatically.


Workflow
---------
1. Install Dependencies
   Installs WebLogic Deploy Tooling (WDT) if not already available and places in `$toolHome/deps/wdt`
   Ensures required packages are present.

2. Discover WebLogic Domain
   Reads connection details from $toolHome/config/on-prem.env
   Connects to AdminServer to extract WebLogic configuration and inventory.
   Generates `$toolHome/out/Discovery_<date>.json`

3. Discover Infrastructure
   Extends the domain inventory with machine, cluster, and infrastructure details.
   Generates `$toolHome/out/infra_output_<date>.json`

4. Discover Datasources
   Extracts JDBC datasource definitions from the domain. 
   Prepares for later reconfiguration with OCI ATP or other databases.

5. Generate OCI Resource Manager Stack
   Creates a stack ZIP file with Infrastructure-as-Code templates.
   Generate `$toolHome/oci/stack/owm_rm_<timestamp>.zip`

6. Upload OCI Resource Manager Stack (Optional)
   By default, the script uploads the stack to the target Object Storage bucket for deployment via OCI Resource Manager.
   This behavior can be controlled using the `skip_transfer` option in `$toolHome/config/on-prem.env` file.
      
7. Archive WebLogic Domain
   Archives Oracle Home, JDK Home, Domain Home, and any custom directories.
   Uses naming convention:
   ```bash
   <machine>-<domain>-domain_home.tar.gz
   <machine>-<domain>-java_home.tar.gz
   <machine>-<domain>-weblogic_home.tar.gz
   <machine>-<domain>-custom_home.tar.gz
   ```
   Note:  It is highly recommended that the WebLogic Domain is in stop state before compressing directories to avoid files being modified between read and write.

8. Upload Archives to OCI (Optional) 
   By default, the script uploads all generated archives to a specified OCI Object Storage bucket.
   This behavior can be controlled using the `skip_transfer` option in `$toolHome/config/on-prem.env` file.


Logs and Error Handling
---------------
Detailed execution logs are available under `$toolHome/logs`.
The main log for this script is `migration_script.log`

If any step fails:

1. Check the error details in `migration_script.log`
2. Fix the issue (for example, missing permissions, incorrect environment variables, or insufficient disk space)
3. Rerun the script:
```bash
$ bash migration_script.sh
```

Since the script is idempotent, previously completed steps will be skipped, and execution will resume from the failed step onward.

Example Run:
```bash
bash migration_script.sh 
2025-09-11 14:39:27  [info] "Installing dependencies" already completed successfully. Skipping.
2025-09-11 14:39:27  [info] "Checking prerequisites" already completed successfully. Skipping.
2025-09-11 14:39:27  [info] "Discovering WebLogic domain" already completed successfully. Skipping.
2025-09-11 14:39:27  [info] "Discovering infrastructure" already completed successfully. Skipping.
2025-09-11 14:39:28  [info] "Discovering datasources" already completed successfully. Skipping.
2025-09-11 14:39:28  [info] "Building OCI Resource Manager stack" already completed successfully. Skipping.
2025-09-11 14:39:28  [info] Stack file created: /home/oracle/mig/oci-weblogic-migration/oci/stack/owm_rm_202509100820.zip
2025-09-11 14:39:28  [info] "Uploading stack to OCI Object Storage bucket wls_mbimg" already completed successfully. Skipping.
2025-09-11 14:39:28  [info] Stack files are uploaded to bucket wls_mbimg inside folder: owm_rm_202509100820. Check /home/oracle/mig/oci-weblogic-migration/logs/upload_unzipped_stack_to_oci_owm_rm_202509100820.log for details
2025-09-11 14:39:28  [info] Archiving WebLogic domain...
2025-09-11 14:48:13  [info] Migration script completed successfully!
 ```


Migrate WLS Domain to OCI Cloud
---------------------------------

### Resource Manager
-------------------
OCI Resource Manager requires the compressed file created in section `Generate OCI Resource Manager Stack`. 

If the `migration_script.sh` was executed with `skip_transfer` option then transfer it to workstation that has access to OracleCloud from a Browser.
Open a new Browser window/Tab and login into your OCI Tenancy. 
Once authenticated, select `Developer Services` from the list of OCI Services.(Top-Left corner)  
From the displayed dropdown, click on  `Developer Services`, select Stacks, then click on `Create Stack` button.
A `Create Stack` Wizard will be displayed. 
Under section `Stack Configuration`, select the option `.Zip file`.
Browse and Upload the Resource Manager stack file. Click Next.   

Else, if the `migration_script.sh` was executed with `skip_transfer` option disabled then, use the PAR URL to launch the `Create Stack` Wizard.

Customize any Stack variable that your environment requires or go with default.
Then click create. 
From the Stack Details, click `Apply`. 

### Resource Manager Provisioning Behavior
--------------------------------------------
Based on the values selected in the ORM Stack variables, Resource Manager will:
* Provision the required number of OCI Compute Instances for WebLogic Servers, along with all associated networking resources (VCN, subnets, gateways, Network Security Gateways, and load balancer).
* Allow the user to either:
  * Create a new VCN.
  * Use a pre-existing VCN.
* Allow the user to provision optional Resources:
  * Bastion Host – Can be provisioned for secure SSH access to private WebLogic compute instances.
  * Public Load Balancer (LB) – Can be added to distribute traffic across managed servers.
  * IAM Policies – Can be created automatically for Object Storage and database access, or the user may use pre-existing policies.
*  Allow the user to select from multiple images for Compute instances:
  * Oracle WebLogic Server Enterprise Edition UCM Image
  * Oracle Weblogic Suite UCM Image
  * Oracle WebLogic Server Enterprise Edition BYOL Image
  * Oracle Weblogic Suite BYOL Image
  * Platform Image(Oracle-Linux-8.10-2025.06.17-0)
* Provides options to recreate the datasource connection strings in OCI for WebLogic domains with JDBC Datasources, using one of the following:
  * Autonomous Database (ADB)
  * OCI Database (DB System)
  * Manual JDBC string replacement
> **Note:**  
> For Multi Data Source (MDS) configurations, only **manual JDBC string replacement** is supported.

> **Prerequisites for JRF WebLogic-enabled domains:**  
> * Databases should be migrated to OCI before running the Resource Manager **Apply** action.  
> * JDBC connection strings must be known before running the Resource Manager **Apply** action.

Required IAM Policies for Non-Admin Users
-------------------------------------------

### Non-Admin User Group Policies
If the user applying the Resource Manager stack is **not an OCI administrator**, the following IAM policies must be created to allow proper provisioning and access:

| Policy Statement | Purpose |
|-----------------|---------|
| `Allow group MyGroup to inspect instance-image in compartment MyCompartment` | To use the WebLogic for OCI images in Marketplace |
| `Allow group MyGroup to use app-catalog-listing in compartment MyCompartment` | To access Marketplace applications catalog |
| `Allow group MyGroup to manage instance-family in compartment MyCompartment` | To create Compute Instances |
| `Allow group MyGroup to manage volume-family in compartment MyCompartment` | To create Block Volumes |
| `Allow group MyGroup to inspect limits in tenancy` | To determine if resources are available in various compartments |
| `Allow group MyGroup to manage virtual-network-family in compartment MyNetworkCompartment` | To create VCNs and subnets |
| `Allow group MyGroup to manage load-balancers in compartment MyNetworkCompartment` | To create a Load Balancer |

### Dynamic Group Policies (for users who unselect "Create Policies" checkbox)

| Policy Statement | Purpose |
|-----------------|---------|
| `Allow dynamic-group <dynamic-group> to manage buckets in compartment MyCompartment` | To create Object Storage buckets |
| `Allow dynamic-group <dynamic-group> to manage objects in compartment MyCompartment` | To upload archives or overwrite existing objects in Object Storage |
| `Allow dynamic-group <dynamic-group> to use autonomous-transaction-processing-family in compartment <compartment>` | To download ATP/ADW database wallet |
| `Allow group MyGroup to manage virtual-network-family in compartment MyNetworkCompartment` | Required for VCN Peering when WLS VCN is not the same as DB VCN and also if `Add Rule for WLS to Access DB` checkbox is selected |

> **Note:**  
> - Replace `MyGroup`, `MyCompartment`, `MyNetworkCompartment`, and `<dynamic-group>` with your actual group names, compartment OCIDs, and dynamic group definitions.  
> - These policies ensure the user has sufficient permissions to provision networking, compute, storage, and WebLogic resources required by the migration stack.  

  
  
### Inputs to Resource Manager
---------------------------------
User will have to provide the following as parameters to terraform:

1. Stack Configuration
   | Variable                          | Description                                                                  | Default |
   | --------------------------------- | ---------------------------------------------------------------------------- | ------- |
   | `OCI Policies`                    | Create IAM policies for Object Storage and ATP DB access. Optional.          | `true`  |
   | `Create a Virtual Cloud Network`  | Create a new Virtual Cloud Network (VCN). Optional if using an existing VCN. | `true`  |
   | `Provision Public Load Balancer`  | Provision a Public Load Balancer. Optional.                                  | `true`  |
   | `Provision Bastion Instance`      | Provision a Bastion host for SSH access. Optional.                           | `true`  |
   | `SSH Public Key`                  | SSH public key for compute instance access. Required.     

2. OCI Object Storage Archive Repository
   | Variable                     | Description                                                 | Default       |
   | ---------------------------- | ----------------------------------------------------------- | ------------- |
   | `Object Storage Bucket name` | Bucket name where on-premise Weblogic archives are stored.. | —             |
   
3. Virtual Cloud Networking
   | Variable                          | Description                                          | Default                    |
   | --------------------------------- | ---------------------------------------------------- | -------------------------- |
   | `Existing Virtual Cloud Network`  | Use an existing VCN. Required if `create_vcn=false`. | —                          |
   | `Virtual Cloud Network Name`      | Name of the VCN (if created).                        | `wls-<terraform state id>` |
   | `Virtual Cloud Network CIDR`      | CIDR for the new VCN.                                | `10.0.0.0/16`              |
  
4. WebLogic Server Compute
   | Variable                      | Description                         | Default                                 |
   | ----------------------------- | ----------------------------------- | --------------------------------------- |
   | `Compute Shape`               | Compute shape for WebLogic servers. | VM.Standard.E4.Flex (1 OCPU, 16 GB RAM) |
   | `WebLogic Server Subnet CIDR` | Subnet CIDR for WebLogic instances. | `10.0.2.0/24`                           |

5. Operating System Image
   | Variable               | Description                                   | Default                                             |
   | ---------------------- | --------------------------------------------- | --------------------------------------------------- |
   | `wlsserver_image_type` | Image license type (Marketplace, Platform.).  | Oracle WebLogic Server Enterprise Edition UCM Image |
   | `terms_and_conditions` | Accept terms if using Marketplace UCM images. | `false`                                             |

6. Load Balancer (Optional)
   | Variable             | Description                                             | Default       |
   | -------------------- | ------------------------------------------------------- | ------------- |
   | `LB Subnet CIDR`     | Subnet CIDR for load balancer.                          | `10.0.3.0/24` |
   | `LB MIN Bandwith`    | Minimum bandwidth (Mbps). Options: 10/100/400/1000/8000 | `10`          |
   | `LB Max Bandwith`    | Maximum bandwidth (Mbps). Options: 10/100/400/1000/8000 | `100`         |

7. Bastion (Optional)
   | Variable              | Description                   | Default                                 |
   | --------------------- | ----------------------------- | --------------------------------------- |
   | `Bastion Subnet CIDR` | Subnet CIDR for bastion host. | `10.0.1.0/24`                           |
   | `Bastion shape`       | Compute shape for bastion.    | VM.Standard.E4.Flex (1 OCPU, 16 GB RAM) |

8. Datasource Options
   For each discovered JDBC datasource, Resource Manager generates a section titled: `DB Connection String #<datasourceName>`
   Each datasource can be recreated in OCI using one of the following strategies:

   A. Manual String Replacement (Always Available)
   | Variable                                    | Description                                                        | Default        |
   | ------------------------------------------- | ------------------------------------------------------------------ | -------------- |
   | `Unique jdbc connection string discovered`  | Original JDBC connection string discovered from on-premise domain. | Auto-populated |
   | `edit jdbc connection string discovered`    | Allows editing the JDBC connection string manually.                | Optional       |
   | `Database Strategy`                         | Select `Manual` to replace the JDBC string manually.               | —              |
    
    **NOTE:** If the datasource is a Multi Data Source (MDS), only Manual JDBC String Replacement is supported.

   B. Autonomous Database (ATP)
   | Variable                                  | Description                                                                                    |
   | ------------------------------------------| --------------------------------------------------------------------------------------------   |
   | `Database Strategy>`                      | Select `Autonomous DB` as the datasource strategy.                                             |
   | `Autonomous Database Compartment`         | Compartment OCID of the target Autonomous Database.                                            |
   | `Autonomous Database>`                    | OCID of the target Autonomous Database.                                                        |
   | `Autonomous Database Service Level`       | ATP workload level (TP, OLTP, DW).                                                             |
   | `Database uses private endpoint`          | Whether the ATP uses a private endpoint.                                                       |
   | `Autonomous Database Network Compartment` | Compartment for ATP networking.                                                                |
   | `Autonomous Database Network`             | Existing VCN for ATP (required if using private endpoint).                                     |
   | `Add Rule for WLS to Access DB`           | Add rules to existing subnet security list for DB access (required if using private endpoint). |


   C. OCI Database System (DB System)
   | Variable                         | Description                                               |
   | ---------------------------------| --------------------------------------------------------- |
   | `Database Strategy`              | Select `OCI DB System` as the datasource strategy.        |
   | `DB System Compartment`          | Compartment OCID of the target DB System.                 |
   | `DB System`                      | OCID of the target DB System.                             |
   | `Database home in the DB System` | OCID of the target DB Home.                               |
   | `Version of the DB System`       | Database major version.                                   |
   | `Database in the DB System`      | OCID of the target Database.                              |
   | `PDB`                            | Pluggable DB (PDB) service name.                          |
   | `DB System Network Compartment`  | Compartment for DB networking.                            |
   | `DB System Network`              | Existing VCN for DB access.                               |
   | `Add Rule for WLS to Access DB`  | Add rules to existing subnet security list for DB access. |
   | `Database Listener Port`         | Port for DB connection (default: 1521).                   |


Restore Process after Stack Apply
-------------------------------------------
Once the ORM stack is applied, the restore process ensures that the cloud environment mirrors the on-premise WebLogic domain.
During the OCI Compute Instances boot process, the cloud-init are initiated which complete the migration of the on-premise domain to OCI.

### Troubleshooting
-------------------
#### Check Cloud-init Status
To verify if the restore process is complete:
```bash
  cloud-init status
  status: done
```   

#### Check Logs
All restore logs are available under `/var/log/owm/` in the compute instances.
```bash
  ls -lrth /var/log/owm
  total 16K
  -rw-r--r--. 1 root   root   2.7K Jul 31 09:42 network-ports.log
  -rw-rw-rw-. 1 oracle oracle    0 Jul 31 09:42 provisioning.log
  -rw-r--r--. 1 root   root   1.4K Jul 31 09:42 os-users.log
  -rw-r--r--. 1 root   root   1.8K Jul 31 09:43 wls-restore.log
  -rw-r--r--. 1 root   root   3.4K Jul 31 09:44 datasource_update.log
```  


Start OCI WebLogic Domain and Verify Services
------------------------------------------------
All OCI Instances (Servers hosting AdminServers and Managed Servers) will be created in a Private Subnet in OCI Virtual Cloud Network. 
To access them, an SSH session should be established via a Bastion Host.
To find the commands to ssh, click on Stack - Application Details Tab and copy the SSH command example given.
The complete ssh command to access the AdminServer should follow this format:

```bash 
ssh -i <private ssh key file> -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' -o 'ProxyCommand ssh -W %h:%p -i <private ssh key file> -l opc <Bastion Public IP>' -l opc <AdminServer Private IP>

$admin-server> sudo su - <same username as on-premise> 
```

Once the cloud-init scripts have completed, SSH to the new AdminServer instance, change directory to the WebLogic Domain Home and bring up your AdminServer. Similarly, start all managed servers. Verify and Test your WebLogic domain to confirm that the migration was successful. 


