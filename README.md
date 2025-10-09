Purpose
-------
The **OCI WebLogic Migration(OWM) Tool** enables lift-and-shift migration of single or multi-node WebLogic domains from on-premises environments to **Oracle Cloud Infrastructure (OCI)**, optionally fronted by a load balancer.  

Key features of the tool:

- The tool **introspects the existing WebLogic Domain** to discover domain configuration, managed servers, clusters, applications, and resources.  
- Based on this discovery, it generates a **tailored Resource Manager stack** that leverages OCI Resource Manager to securely provision and configure:  
  - **OCI Networking resources** (VCN, subnets, gateways, route tables, and security lists)  
  - **Compute Instances** to host the discovered WebLogic domain  
  - Optional **load balancers** for distributing traffic across WebLogic managed servers  
- The tool updates **JDBC datasource configuration files** in the domain so that WebLogic servers in OCI can connect to target databases.  

> **Important:**  
> This tool does **not** migrate on-premises databases to OCI.

---

Terminology
---------
| Term | Description                                                                                                                                                                                                                                                               |
|------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **OCI** | Oracle Cloud Infrastructure.                                                                                                                                                                                                                                              |
| **On-Premise** | Refers to the source environment where the WebLogic domain currently resides.                                                                                                                                                                                             |
| **OWM** | OCI WebLogic Migration Tool; the tool used to migrate on-premises WebLogic domains to OCI.                                                                                                                                                                                |
| **AdminServer host** | The VM hosting the AdminServer of the on-premises WebLogic domain.                                                                                                                                                                                                        |
| **Custom directories** | File system paths referenced by the WebLogic domain configuration that are **outside** the standard three categories (Domain Home, Middleware Home, Java Home). <br>**Example:** External trust stores or keystores located outside the Domain or Middleware directories. |
| **OS** | Operating System installed on a host, e.g., Oracle Linux.                                                                                                                                                                                                                 |
| **Archives** | Compressed tarball files created from the WebLogic domain’s **Domain Home**, **Middleware Home**, and **Java Home** directories for migration to OCI.                                                                                                                     |


---

Requirements
----------------------------
To use the tool, ensure the following prerequisites are met:

### 1. On-Premises Requirements
- **Operating System:** Supports Linux environments, including Oracle Linux (OL) and RHEL-compatible distributions.
- **File system permissions:** The tool must be installed on the **AdminServer host**. The user must have **read/write permissions** on WebLogic Domain, Oracle Middleware, and Java Home directories.
- **SSH Connectivity:** Passwordless SSH must be established from the AdminServer host to all Managed Server hosts.
    - **For SSH Passwords:** Configure passwordless SSH between the AdminServer and Managed Servers.
    - **For SSH Key Authentication:** Use SSH agent to store your key and passphrase for seamless connectivity between the AdminServer and Managed Servers.
  > **Note:** Test SSH connectivity from the AdminServer to each Managed Server using `ssh <managed-server-host>` to ensure authentication works without prompting for a password or passphrase.
- **Storage space:** Each host must have sufficient disk space to archive **Oracle Home**, **JDK Home**, **Domain Home**, and any **custom directories**.

### 2. Oracle Cloud Requirements
- **Oracle Cloud Account (Tenancy):** Resources discovered on-premises will be recreated under an OCI Tenancy.
- **OCI Compartment:** Required to logically group all resources created by the OWM tool.
- **OCI Resource Manager:** Permissions to create, plan, and apply stacks.
- **OCI Permissions:** Ability to create and manage the following resources:
    - Virtual Cloud Networks (VCNs)
    - Compute Instances
    - Block Storage
    - Load Balancers (Optional)

> Refer to [Required IAM Policies for Non-Admin Users](#Non-Admin-User-Group-Policies) for detailed IAM policy requirements.

### 3. Optional IAM Policies
If stack users need to create IAM policies in the **Default Identity Domain** under the **root compartment**, additional policy management permissions are required.  
Refer to the detailed [**Required IAM Policies**](#required-iam-policies) section later in this document.

---

Installing Weblogic Migration Tool
----------------------------------------
* Initiate a Secure Shell (SSH) connection to the **AdminServer host**, utilizing a user account with read and write file system permissions. This step enables secure remote access and interaction with the server.
* Obtain a local copy of the OWM Tool repository in a folder where the user has read and write permissions.
  * If downloading manually, extract the repository contents to this folder.
* If you plan to clone the repository using Git, ensure that the latest version of Git is installed on the host. 
  * Download the most recent release of GIT from  [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  * Clone the repository with the commands in a folder where the user has read and write permissions:
 
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

**Note** '$toolHome' refers to the folder where the OWM Tool repository contents are downloaded or cloned.

---

WebLogic Migration Script
-----------------------
This repository contains a consolidated script migration_script.sh that automates the complete migration of an on-premise WebLogic domain to Oracle Cloud Infrastructure (OCI).
The script combines all required tasks into a single workflow:

1. Install dependencies
2. Discover WebLogic domain and infrastructure
3. Discover datasources
4. Generate OCI Resource Manager stack
5. Upload stack to OCI Object Storage Bucket(Optional)
6. Archive WebLogic domain
7. Upload archives to OCI Object Storage Bucket(Optional)

Usage
----------------------------------------
### Step 1.  Declare WebLogic source domain details in $toolHome/config/on-prem.env

Example:

```bash
######################################################################
# ssh_user:  An Operating System user with read and write permissions
#            on WebLogic Domain, Oracle Middleware and Java Home.
# Example oracle
######################################################################
ssh_user=oracle

######################################################################
# CLEAR VALUE (leave blank) if ssh_password_file is set.
# ssh_private_key_file:  The file name of a file that contains the user’s private key
#                        to use when authenticating with a public/private key pair.
# Example /home/oracle/.ssh/id_rsa
######################################################################
ssh_private_key_file=/home/oracle/.ssh/id_rsa

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
# java_home  :  The location of the JDK that WebLogic Server uses for execution 
                and was used during its installation.
######################################################################
domain_home=/u01/data/domains/test_domain
oracle_home=/u01/app/oracle/middleware
java_home=/u01/jdk

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
bucket_name=test_bucket
compartment_ocid=ocid1.compartment.oc1..aaaaxxxxxxxxxxxxxxhiyqarxuguncyfwnroeppa2kmva
tenancy_namespace=abcxxxyyyzzz  
```

### Step 2. Pre-requisite Steps for executing the Migration Script

Before executing the migration script `migration_script.sh`, ensure the following pre-requisites are completed:

1. **Internet Connection(Optional)**  
   The WebLogic Migration Tool requires access to GitHub to download required libraries (WebLogic Deployment Tool) to discover the source WebLogic environment.
   - Alternatively, specific releases can be manually downloaded and placed in `$toolHome/deps/wdt`.

2. **All Source domain Servers Must Be Up and Running (Required)**  
    In the source environment, all WebLogic Server hosts (AdminServer and Managed Servers) are expected to be **up and running**. This is mandatory to ensure the migration script can successfully connect, discover, and archive domain configurations.

3. **Manual Archive Transfer**
   If you plan to perform step 5 (upload stack) and step 7 (upload archives) manually, set `skip_transfer=true` in `on-prem.env`.
   Transfer the archives manually by following the instructions in `$toolHome/logs/migration_script.log`.
   The archives are available inside `$toolHome/out` on the **AdminServer host**, provided the **AdminServer host** has enough space to accommodate the archives from all the hosts.

4. **OCI-CLI Installation (Optional)**  
   - If you want the script to handle uploads automatically, install the OCI-CLI on the **AdminServer host**.
   - Installation and configuration details: [OCI CLI Documentation](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
     **Installation Steps:**

    ```bash
    # Enable the Oracle Linux Developer repository
    sudo dnf -y install oraclelinux-developer-release-el8
    
    # Install OCI CLI package
    sudo dnf install python36-oci-cli
    
    # Upgrade pip and required dependencies
    pip3 install --user --upgrade pip
    pip3 install --user six==1.15.0 --upgrade
    pip3 install --user click==8.0.4
    pip3 install --user oci==2.157.0 --upgrade
    ``` 
   
   - To verify installation, run:
     ```bash
     oci iam region list
     ``` 
     **IAM Policy Requirement:**  
     The user running this command must belong to a group with the following policy at the tenancy level:
     ```bash
     Allow group <YourGroupName> to inspect regions in tenancy 
     ``` 
   - **Required User Policies for Non-Admin Users** (if automatic upload is needed):
      1. Allow group `Non-Admin` to manage object-family in the compartment specified in `on-prem.env` for storage bucket details.
      2. Allow group `Non-Admin` to read buckets in the tenancy.

5. **SSH Authentication**  
   The **AdminServer host** of the source domain must have **passwordless SSH authentication** established to all **WebLogic Managed Server** Linux hosts.  
   This ensures seamless remote operations during migration.

    **Example:**
    On the AdminServer host, verify SSH connectivity to each Managed Server without a password prompt.

    ```bash
    # Get the full hostname of the AdminServer
    hostname -f
    mbnjrf-wls-0.wlsubnetfrjnbm.mbnjrfvcn.oraclevcn.com
    
    # Test SSH connection to each Managed Server host
    [oracle@mbnjrf-wls-0 ~]$ ssh mbnjrf-wls-1.wlsubnetfrjnbm.mbnjrfvcn.oraclevcn.com
    [oracle@mbnjrf-wls-1 ~]$ exit
    ```
    Repeat this process from the **AdminServer host** to all hosts in the WebLogic domain to confirm passwordless SSH access is properly configured.

### Step 3. Run the migration script from the $toolHome/bin directory.
 
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
   Archives **Oracle Home, JDK Home, Domain Home, and any custom directories**.
   
   **Archive Naming Convention**
   ```bash
   <machine>-<domain>-domain_home.tar.gz
   <machine>-<domain>-java_home.tar.gz
   <machine>-<domain>-weblogic_home.tar.gz
   <machine>-<domain>-custom_home.tar.gz
   ``` 
  
8. Upload Archives to OCI (Optional) 
   By default, the script uploads all generated archives to a specified OCI Object Storage bucket.
   This behavior can be controlled using the `skip_transfer` option in `$toolHome/config/on-prem.env` file.


Logs and Error Handling
---------------
Detailed execution logs are available under `$toolHome/logs`.
The main log for this script is `migration_script.log`. Log is always appended to, so all previous execution attempts will remain in the log.
To get the log for only the most recent script execution, either move the existing log to another location or delete it before re-running the script.

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
2025-09-17 13:52:15  [info] Installing dependencies...
2025-09-17 13:52:15  [info] Checking prerequisites...
2025-09-17 13:52:17  [info] Discovering WebLogic domain...
2025-09-17 13:52:56  [info] Discovering infrastructure...
2025-09-17 13:53:14  [info] Discovering datasources...
2025-09-17 13:53:25  [info] Building OCI Resource Manager stack...
2025-09-17 13:53:25  [info] Stack file created: /home/oracle/mig/oci-weblogic-migration/oci/stack/owm_rm_202509171353.zip
2025-09-17 13:53:25  [info] Uploading owm_rm_202509171353.zip to OCI Object Storage bucket wls_mbimg...
2025-09-17 13:53:28  [info] owm_rm_202509171353.zip uploaded to bucket wls_mbimg.
2025-09-17 13:53:28  [info] Generated PAR URL (valid 6 months): https://ax8cfrmecktw.objectstorage.us-ashburn-1.oci.customer-oci.com/p/ItgGDQVxon0cVpmqP4yp5E3fZkX2xMJ4LKydmQLTjVrb8DAWGh-0n0XZwTbOA8kk/n/ax8cfrmecktw/b/wls_mbimg/o/owm_rm_202509171353.zip
2025-09-17 13:53:28  [info] Archiving WebLogic domain...
2025-09-11 14:11:13  [info] Migration script completed successfully!
 ```

---

Migrate WLS Domain to OCI Cloud
---------------------------------

### Resource Manager
OCI Resource Manager requires the compressed stack file created in the **Generate OCI Resource Manager Stack** step by `migration_script.sh`.

#### Step 1: Pre-requisites for Resource Manager
Before launching the stack, ensure the following are completed:

1. **Database Migration (for JRF WebLogic-enabled domains)**  
   Complete the on-premise database migration to OCI-DB or ATP-DB as appropriate before running the Resource Manager **Apply** action.**.

2. **JDBC Connection Strings (for JRF WebLogic-enabled domains)**  
   JDBC connection strings of the OCI Database must be known before running the Resource Manager **Apply** action.

3. **IAM Policies for Non-Admin Users**  
   Ensure you have the correct IAM permissions. For Non-Admin users, see [Required IAM Policies for Non-Admin Users](#non-admin-user-group-policies).

4. **Dynamic Group Policies**  
   If you unselect the **"Create Policies"** checkbox during stack creation, ensure appropriate dynamic group policies are already in place. See [Dynamic Group Policies](#dynamic-group-policies-for-users-who-unselect-create-policies-checkbox) for details.

5. **Marketplace Terms (if using UCM images)**  
   If you plan to use an Oracle WebLogic for OCI UCM image from the Marketplace, you must **accept the terms** for that listing in advance.
    - If you do not accept the terms and select a UCM image during stack creation, the Resource Manager **Apply job will fail**.
    
#### Step 2: Collect the Stack File
- **If `migration_script.sh` was executed with `skip_transfer=true`:**  
  Transfer the stack file to a workstation that has access to Oracle Cloud via a browser.

- **If `migration_script.sh` was executed with `skip_transfer=false`:**
   - **Windows:** Use the PAR URL generated by the script to access the stack directly.
   - **Linux:** Download the `stack.zip` locally using the PAR URL.

#### Step 3: Launch the Stack
1. Open a browser and log in to your OCI Tenancy.
2. From the top-left corner, select **Developer Services**.
3. In the dropdown, click **Stacks**, then click **Create Stack**.
4. In the **Create Stack** wizard, under **Stack Configuration**, select **.Zip file** and upload the collected stack file.
5. Click **Next**.
6. Customize any stack variables required for your environment (see [Inputs to Resource Manager](#inputs-to-resource-manager)), or leave them as default.
7. Click **Create**.
8. From the **Stack Details** page, click **Apply** to launch the stack and provision the OCI resources.

### Resource Manager Provisioning Behavior

Based on the values selected in the ORM Stack variables, Resource Manager will:
* Provision the required number of OCI Compute Instances for WebLogic Servers, along with all associated networking resources (VCN, subnets, gateways, Network Security Gateways, and load balancer).
* Allow the user to either:
  * Create a new VCN.
  * Use a pre-existing VCN.
* Allow the user to provision optional Resources:
  * Bastion Host – Can be provisioned for secure SSH access to private WebLogic compute instances.
  * Public Load Balancer (LB) – Can be added to distribute traffic across managed servers.
  * IAM Policies – Can be created automatically for Object Storage and database access, or the user may use pre-existing policies.
* Allow the user to select from multiple images for Compute instances:
  * Oracle WebLogic Server Enterprise Edition UCM Image
  * Oracle Weblogic Suite UCM Image
  * Oracle WebLogic Server Enterprise Edition BYOL Image
  * Oracle Weblogic Suite BYOL Image
* Provides options to recreate the datasource connection strings in OCI for WebLogic domains with JDBC Datasources, using one of the following:
  * Autonomous Database (ADB)
  * OCI Database (DB System)
  * Edit JDBC string
> **Note:**  
> For Multi Data Source (MDS) configurations for RAC DB, only **Edit JDBC string** option is supported.

---

Inputs to Resource Manager
---------------------------

User will have to provide the following as parameters to the Resource Manager:

#### 1. Stack Configuration
| Variable                          | Description                                                                  | Default |
| --------------------------------- | ---------------------------------------------------------------------------- | ------- |
| `OCI Policies`                    | Create IAM policies for Object Storage and ATP DB access. Optional.          | `true`  |
| `Create a Virtual Cloud Network`  | Create a new Virtual Cloud Network (VCN). Optional if using an existing VCN. | `true`  |
| `Provision Public Load Balancer`  | Provision a Public Load Balancer. Optional.                                  | `true`  |
| `Provision Bastion Instance`      | Provision a Bastion host for SSH access. Optional.                           | `true`  |
| `SSH Public Key`                  | SSH public key for compute instance access. Required.                        | —       |

#### 2. OCI Object Storage Archive Repository
| Variable                     | Description                                                 | Default |
| ---------------------------- | ----------------------------------------------------------- | ------- |
| `Object Storage Bucket name` | Bucket name where on-premise WebLogic archives are stored. | —       |

#### 3. Virtual Cloud Networking
| Variable                          | Description                                                  | Default                    |
| --------------------------------- | ------------------------------------------------------------ | -------------------------- |
| `Existing Virtual Cloud Network`  | OCID of the existing VCN. Required if `create_vcn=false`.    | —                          |
| `Virtual Cloud Network Name`      | Name of the new VCN if Use an Existing VCN is not selected   | `wls-<terraform state id>` |
| `Virtual Cloud Network CIDR`      | CIDR for the new VCN if Use an Existing VCN is not selected. | `10.0.0.0/16`              |

#### 4. WebLogic Server Compute
| Variable                      | Description                         | Default                                 |
| ----------------------------- | ----------------------------------- | --------------------------------------- |
| `Compute Shape`               | Compute shape for WebLogic servers. | VM.Standard.E4.Flex (1 OCPU, 16 GB RAM) |
| `WebLogic Server Subnet CIDR` | Subnet CIDR for WebLogic instances. | `10.0.2.0/24`                           |

#### 5. Operating System Image
| Variable               | Description                                   | Default                                             |
| ---------------------- | --------------------------------------------- | --------------------------------------------------- |
| `wlsserver_image_type` | Image license type (Marketplace, Platform).  | Oracle WebLogic Server Enterprise Edition UCM Image |
| `terms_and_conditions` | Accept terms if using Marketplace UCM images. | `false`                                             |

#### 6. Load Balancer (Optional)
| Variable             | Description                                             | Default       |
| -------------------- | ------------------------------------------------------- | ------------- |
| `LB Subnet CIDR`     | Subnet CIDR for load balancer.                          | `10.0.3.0/24` |
| `LB MIN Bandwidth`   | Minimum bandwidth (Mbps). Options: 10/100/400/1000/8000 | `10`          |
| `LB Max Bandwidth`   | Maximum bandwidth (Mbps). Options: 10/100/400/1000/8000 | `100`         |

#### 7. Bastion (Optional)
| Variable              | Description                   | Default                                 |
| --------------------- | ----------------------------- | --------------------------------------- |
| `Bastion Subnet CIDR` | Subnet CIDR for bastion host. | `10.0.1.0/24`                           |
| `Bastion shape`       | Compute shape for bastion.    | VM.Standard.E4.Flex (1 OCPU, 16 GB RAM) |

#### 8. Datasource Options
For each discovered JDBC datasource, Resource Manager generates a section titled: `DB Connection String #<datasourceName>`.  
Each datasource can be recreated in OCI using one of the following strategies:

**A. Edit JDBC String (Always Available)**
| Variable                                    | Description                                                        | Default        |
| ------------------------------------------- | ------------------------------------------------------------------ | -------------- |
| `Unique jdbc connection string discovered`  | Original JDBC connection string discovered from on-premise domain. | Auto-populated |
| `edit jdbc connection string discovered`    | Allows editing the JDBC connection string.                | Optional       |
| `Database Strategy`                         | Select `Edit JDBC String` to replace the JDBC string directly.     | —              |

> **Note:** If the datasource is a Multi Data Source (MDS) in case of RAC DB, only JDBC String Replacement is supported.                                                

> **Warning:** If VCN peering is required (when WebLogic VCN and Database VCN are different), it must be configured manually by following the [Manual VCN Peering guide](https://docs.oracle.com/en/cloud/paas/weblogic-cloud/user/configure-database-parameters.html#GUID-6A39A2A7-EF6C-408E-B5C7-C44089A9B134__MANUAL_VCN_PEERING). This must be done **before starting the servers**, otherwise the server start will fail.  


**B. Autonomous Database (ATP)**
| Variable                                  | Description                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `Database Strategy`                        | Select `Autonomous DB` as the datasource strategy.                                               |
| `Autonomous Database Compartment`          | Compartment OCID of the target Autonomous Database.                                              |
| `Autonomous Database`                      | OCID of the target Autonomous Database.                                                         |
| `Autonomous Database Service Level`        | ATP workload level (TP, OLTP, DW).                                                              |
| `Database uses private endpoint`           | Whether the ATP uses a private endpoint.                                                        |
| `Autonomous Database Network Compartment`  | Compartment for ATP networking.                                                                 |
| `Autonomous Database Network`              | Existing VCN for ATP (required if using private endpoint).                                        |
| `Add Rule for WLS to Access DB`            | Add rules to existing subnet security list for DB access (required if using private endpoint).   |


**C. OCI Database System (DB System)**
| Variable                         | Description                                               |
| ---------------------------------| --------------------------------------------------------- |
| `Database Strategy`               | Select `OCI DB System` as the datasource strategy.        |
| `DB System Compartment`           | Compartment OCID of the target DB System.                 |
| `DB System`                       | OCID of the target DB System.                             |
| `Database home in the DB System`  | OCID of the target DB Home.                               |
| `Version of the DB System`        | Database major version.                                   |
| `Database in the DB System`       | OCID of the target Database.                              |
| `PDB`                             | Pluggable DB (PDB) service name.                          |
| `DB System Network Compartment`   | Compartment for DB networking.                            |
| `DB System Network`               | Existing VCN for DB access.                               |
| `Add Rule for WLS to Access DB`   | Add rules to existing subnet security list for DB access. |
| `Database Listener Port`          | Port for DB connection (default: 1521).                   |


Required IAM Policies
-----------------------

### Non-Admin User Group Policies
If the user applying the Resource Manager stack is **not an OCI administrator**, your OCI administrator must first grant the following **user group policies** to allow proper provisioning and access:

| Policy Statement | Purpose                                                         | Policy Location              |
|------------------|-----------------------------------------------------------------|------------------------------|
| `Allow group Non-Admin to read buckets in tenancy` | To check if Object Storage bucket is pre-existing               | Root Compartment             |
| `Allow group Non-Admin to inspect tenancies in tenancy` | To locate the home region for the tenancy                       | Root Compartment             |
| `Allow group Non-Admin to inspect limits in tenancy` | To determine if resources are available in various compartments | Root Compartment             |
| `Allow group Non-Admin to manage object-family in compartment MyCompartment` | To create Object Storage bucket and upload the archives         | Bucket Compartment           |
| `Allow group Non-Admin to manage instance-family in compartment MyCompartment` | To create Compute Instances                                     | Stack Compartment            |
| `Allow group Non-Admin to manage volume-family in compartment MyCompartment` | To create Block Volumes                                         | Stack Compartment            |
| `Allow group Non-Admin to manage orm-family in compartment MyCompartment` | To create Resource Manager stacks                               | Stack Compartment            |
| `Allow group Non-Admin to manage virtual-network-family in compartment MyNetworkCompartment` | To create networking resources (VCNs, Subnets, Gateways)        | WebLogic Network Compartment |
| `Allow group Non-Admin to manage dns-family in compartment MyNetworkCompartment` | To manage DNS resources(Zones and Private views)                | WebLogic Network Compartment |

#### Optional Policies

The following policies are required **only if specific features are enabled**:

| Policy Statement | Purpose | Policy Location              |
|------------------|---------|------------------------------|
| `Allow group Non-Admin to manage load-balancers in compartment MyNetworkCompartment` | To create and manage Load Balancers (required if **"Provision Load Balancer"** checkbox is selected) | WebLogic Network Compartment |
| `Allow group Non-Admin to manage orm-private-endpoints in compartment MyNetworkCompartment` | To create Private Endpoints (required **only if "Provision Bastion Instance"** checkbox is **not** selected)                               | WebLogic Network Compartment |

> **Note:** These policies are conditional and should only be applied when the corresponding feature checkboxes are selected during Stack Apply.


---

### Dynamic Group Policies (for users who unselect **"Create Policies"** checkbox)

When Compute instances are started, certain scripts make OCI API calls. These instances gain permissions through **dynamic groups** and associated **policies**.

You have two options:
- **Pre-create the policies** before stack creation.
- **Let the Terraform scripts** create them automatically by selecting the **OCI Policies** option.

If you want Terraform to create the dynamic groups and policies, and you are **not an OCI administrator**, your OCI administrator must first grant the following **user group policies**:

| Policy Statement | Purpose | Policy Location |
|------------------|---------|-----------------|
| `Allow group MyGroup to manage dynamic-groups in tenancy` | To create dynamic groups | Root Compartment |
| `Allow group MyGroup to manage policies in tenancy` | To create policies in the root compartment | Root Compartment |


### Policies Created When **"Create Policies"** Checkbox Is Selected
The following **dynamic group and network policies** are **automatically created** if the **"Create Policies"** checkbox is selected.

> **Important**  
> If the checkbox is **not selected**, these policies must be **added manually** by your OCI administrator.

| Policy Statement | Purpose | Policy Location |
|------------------|----------|-----------------|
| `Allow dynamic-group <dynamic-group> to read buckets in tenancy` | To find the compartment where Object Storage buckets exist | Root Compartment |
| `Allow dynamic-group <dynamic-group> to read objects in compartment <BucketCompartment>` | To upload archives or overwrite existing objects in Object Storage | Bucket Compartment |
| `Allow dynamic-group <dynamic-group> to use instance-family in compartment <ComputeCompartment>` | Required for instance-level operations such as starting or stopping compute instances during migration | Stack Compartment |
| `Allow dynamic-group <dynamic-group> to manage volume-family in compartment <ComputeCompartment>` | Required to attach or detach block volumes and manage storage used by migrated servers | Stack Compartment |
| `Allow dynamic-group <dynamic-group> to inspect virtual-network-family in compartment <NetworkCompartment>` | Required to inspect VCN and subnet information for network configuration validation | Weblogic Network Compartment |


#### ATP-DB Policy (Optional)
If the migrated domain uses an Autonomous Database (ATP/ADW), The following policy is required to download the ATP or ADW database wallet: 

| Policy Statement | Policy Location |
| `Allow dynamic-group <dynamic-group> to use autonomous-transaction-processing-family in compartment MyCompartment` | Database Compartment   |


#### VCN Peering Policies (Optional)
If VCN Peering is required (i.e., when the WebLogic VCN is different from the DB VCN), the following policies are needed:

| Policy Statement | Policy Location |
|------------------|----------------|
| `Allow dynamic-group <dynamic-group> to manage virtual-network-family in compartment MyDBNetworkCompartment` | DB Network Compartment |
| `Allow dynamic-group <dynamic-group> to manage virtual-network-family in compartment MyNetworkCompartment` | WebLogic Network Compartment |


#### WLS to DB Access Policy (Optional)
The following policy is required only if the **"Add Rule for WLS to Access DB"** checkbox is selected:

| Policy Statement                                                                                             | Policy Location        |
|--------------------------------------------------------------------------------------------------------------|------------------------|
| `Allow dynamic-group <dynamic-group> to manage virtual-network-family in compartment MyDBNetworkCompartment` | DB Network Compartment |

> **Note:**
> - Replace `MyGroup`, `MyCompartment`, `MyDBNetworkCompartment`, and `<dynamic-group>` with your actual group names, compartment OCIDs, and dynamic group definitions.
> - These policies ensure the user has sufficient permissions to provision networking, compute, storage, and WebLogic resources required by the migration stack.

---

Restore Process after Stack Apply
-------------------------------------------
Once the ORM stack is applied, the restore process ensures that the cloud environment mirrors the on-premise WebLogic domain.  
During the OCI Compute Instances boot process, `cloud-init` is initiated which completes the migration of the on-premise domain to OCI.

**Important:** No WebLogic Server domain servers or Node Manager processes are started automatically after the restore.  
You should first review the migrated contents before starting services.  
See [Start OCI WebLogic Domain and Verify Services](#start-oci-weblogic-domain-and-verify-services) for the next steps.

### Troubleshooting

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

---

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

---

Known Issues
-------------

### 1. Migration script fails during infrastructure discovery

When running the migration script, you may encounter the following error:

```bash
bash migration_script.sh
2025-09-24 06:03:46 [info] Installing dependencies...
2025-09-24 06:03:47 [info] Checking prerequisites...
2025-09-24 06:03:57 [info] Discovering WebLogic domain...
2025-09-24 06:04:20 [info] Discovering infrastructure...
2025-09-24 06:04:30 [error] "Discovering infrastructure" failed. Check /home/domain/mig/oci-weblogic-migration/logs/migration_script.log for details. Run migration_script.sh again after resolving the issue.
2025-09-24 06:04:30 [error] Migration failed.
```

In the log file (/home/domain/mig/oci-weblogic-migration/logs/migration_script.log), you may see an error similar to:

```bash
<SEVERE> <discover_infra> <WLSDPLY-20035> <verifySSH encountered an unexpected runtime exception.
Please file an issue on GitHub and attach the log file and stdout. Exception: exceptions.IndexError>
```

#### Cause
This is an intermittent issue triggered during the infrastructure discovery phase by the verifySSH step.

#### Workaround
Re-run the migration script. Previous successful steps will be skipped automatically, and the script should proceed normally:

```bash
bash migration_script.sh
2025-09-24 06:05:49  [info] "Installing dependencies" already completed successfully. Skipping.
2025-09-24 06:05:49  [info] "Checking prerequisites" already completed successfully. Skipping.
2025-09-24 06:05:49  [info] "Discovering WebLogic domain" already completed successfully. Skipping.
2025-09-24 06:05:49  [info] Discovering infrastructure...
...
2025-09-24 06:08:16  [info] Migration script completed successfully!
```

---

### 2. Migration script fails in Archive Domain Step 

If the script fails during the **Archive Domain** step due to **insufficient disk space** on any of the nodes, the log file will display a **TODO** message.
These TODO messages include the exact commands that must be executed **manually** on the affected host to complete the archive creation process.

**Example:**
If the migration_script.log shows:

```bash

WARNING Messages:

        1. WLSDPLY-05027: Not enough space on mbnjrf_machine_1 to create the archives. Please run the commands manually mentioned in the TODO to create the archive, scp to the admin host and upload to bucket.
        2. WLSDPLY-05027: Not enough space on mbnjrf_machine_2 to create the archives. Please run the commands manually mentioned in the TODO to create the archive, scp to the admin host and upload to bucket.

TODO Messages:

        1. WLSDPLY-06042: Please create the FILE_STORE in the archive file at /usr/bin/tar czf /tmp/mbnjrf_machine_1-mbnjrf_domain-java_home.tar.gz --exclude='.pid' --exclude='.state' --exclude='.core' --exclude='diag/ofm/*/*/lck/*.lck' --exclude='servers/*/logs/*.*' --exclude='*.log*[0-9]' --exclude='*.log' --exclude='*.out' --exclude='*.out*[0-9]' --exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*' /u01/app/oracle/jdk .
        2. WLSDPLY-06042: Please create the FILE_STORE in the archive file at /usr/bin/tar czf /tmp/mbnjrf_machine_1-mbnjrf_domain-domain_home.tar.gz --exclude='.pid' --exclude='.state' --exclude='.core' --exclude='diag/ofm/*/*/lck/*.lck' --exclude='servers/*/logs/*.*' --exclude='*.log*[0-9]' --exclude='*.log' --exclude='*.out' --exclude='*.out*[0-9]' --exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*' /u01/data/domains/mbnjrf_domain .
        3. WLSDPLY-06042: Please create the FILE_STORE in the archive file at /usr/bin/tar czf /tmp/mbnjrf_machine_1-mbnjrf_domain-weblogic_home.tar.gz --exclude='.pid' --exclude='.state' --exclude='.core' --exclude='diag/ofm/*/*/lck/*.lck' --exclude='servers/*/logs/*.*' --exclude='*.log*[0-9]' --exclude='*.log' --exclude='*.out' --exclude='*.out*[0-9]' --exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*' /u01/app/oracle/middleware .
        4. WLSDPLY-06042: Please create the FILE_STORE in the archive file at /usr/bin/tar czf /tmp/mbnjrf_machine_1-mbnjrf_domain-custom_dirs.tar.gz --exclude='.pid' --exclude='.state' --exclude='.core' --exclude='diag/ofm/*/*/lck/*.lck' --exclude='servers/*/logs/*.*' --exclude='*.log*[0-9]' --exclude='*.log' --exclude='*.out' --exclude='*.out*[0-9]' --exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*' /u01/data/domains/mbnjrf_domain/wlsdeploy/applications .
        5. WLSDPLY-06042: Please create the FILE_STORE in the archive file at /usr/bin/tar czf /tmp/mbnjrf_machine_2-mbnjrf_domain-java_home.tar.gz --exclude='.pid' --exclude='.state' --exclude='.core' --exclude='diag/ofm/*/*/lck/*.lck' --exclude='servers/*/logs/*.*' --exclude='*.log*[0-9]' --exclude='*.log' --exclude='*.out' --exclude='*.out*[0-9]' --exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*' /u01/app/oracle/jdk .
        6. WLSDPLY-06042: Please create the FILE_STORE in the archive file at /usr/bin/tar czf /tmp/mbnjrf_machine_2-mbnjrf_domain-domain_home.tar.gz --exclude='.pid' --exclude='.state' --exclude='.core' --exclude='diag/ofm/*/*/lck/*.lck' --exclude='servers/*/logs/*.*' --exclude='*.log*[0-9]' --exclude='*.log' --exclude='*.out' --exclude='*.out*[0-9]' --exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*' /u01/data/domains/mbnjrf_domain .
        7. WLSDPLY-06042: Please create the FILE_STORE in the archive file at /usr/bin/tar czf /tmp/mbnjrf_machine_2-mbnjrf_domain-weblogic_home.tar.gz --exclude='.pid' --exclude='.state' --exclude='.core' --exclude='diag/ofm/*/*/lck/*.lck' --exclude='servers/*/logs/*.*' --exclude='*.log*[0-9]' --exclude='*.log' --exclude='*.out' --exclude='*.out*[0-9]' --exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*' /u01/app/oracle/middleware .
```

#### Workaround
Then, log in to that specific host and run the indicated command manually.

After the archive is successfully created:
1. Upload the generated archive file to the designated **Object Storage bucket** manually **or**
2. Use the **OCI CLI** to upload the file if the OCI CLI is installed on the instance.

**Example (OCI CLI upload):**
```bash
oci os object put --bucket-name <bucket_name> --file <archive_file_path> --force
```

Ensure that all required domain archives are uploaded before proceeding with stack creation.

---

## Limitations

- Domains created with WebLogic Server 12.2.1.3 are not supported for migration or automation with this tool.


---

### 3. Error when starting Managed Servers (Hostname Verification Failure)

You may encounter an error when attempting to start managed servers:

```bash
<Warning> <Security> <BEA-090504> <Certificate chain received from xxxx.example.com - 10.0.2.229 failed hostname verification check. Certificate contained CN=xxxx but check expected xxxx.example.com>
```

#### Cause
This occurs because the SSL certificate presented by the server does not match the expected hostname.  
For example, the certificate contains the common name **`CN=xxxx`**, while WebLogic expects **`xxxx.example.com`**.  
This mismatch causes hostname verification to fail.

#### Workaround
If the source domain is configured with the following in `config.xml`:
```bash
weblogic.security.SSL.ignoreHostnameVerification=true
```

Then you must apply the same setting manually for each managed server:

1. Start the **Admin Server**.
2. Log in to the **WebLogic Administration Console**.
    - Navigate to: **Environment** → **Servers** → *[Managed Server Name]* → **Server Start** tab.
3. For each Managed Server, add the following JVM option in the **Arguments** field:   
    ```bash
    -Dweblogic.security.SSL.ignoreHostnameVerification=true
    ```
4. Use the `startManagedServer.sh` script to start the Managed Servers.

---

### 4. Error when starting Managed Server in WebLogic 12.2.1.4 (secure mode)

When starting a Managed Server with WebLogic 12.2.1.4 in secure mode, you may see errors such as:

```bash
<BEA-003111> <No channel exists for replication calls for cluster domainCcluster>
<BEA-000386> <Server subsystem failed. Reason: No replication server channel for managedserver1>
Server state changed to FAILED
```

#### Cause
In secure mode, WebLogic expects replication channels for cluster communication.
If no replication channel is configured, the Managed Server startup fails.

#### Workaround 
Disable secure replication in the domain configuration (config.xml) before starting the servers.

```bash
<secure-replication-enabled>false</secure-replication-enabled>
```

**Note** This issue has been addressed in the latest code base, and the configuration is automatically handled by the migration tool. No manual action is required.

---

Limitations
------------

- Domains created with WebLogic Server 12.2.1.3 are not supported for migration with this tool.
- For domains with multiple managed servers using different listen ports, the load balancer configuration must be performed manually, and the backend targets must be adjusted accordingly.


