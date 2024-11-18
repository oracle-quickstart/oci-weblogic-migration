Purpose
-------
Oracle WebLogic Migration tool lifts and shifts single/multi node Weblogic Domain to Oracle Cloud Infrastructure optionally fronted
by a load balancer. The solution will create only one stack at time and further modifications  will be done on the same stack.

The Oracle WebLogic Migration tool is designed to facilitate a smooth lift-and-shift migration of WebLogic domains to the cloud. The solution will introspect a Weblogic Domain and creates a tailored Resource Manager Stack that leverages the capabilities of OCI Resource Manager service to securely create OCI Network, Compute Instances to host the WebLogic Domain discovered.    


Requirements
-----------------------------

*On-Premise Requirements*

To deploy the software, ensure the following prerequisites are met:

    Oracle Linux compatibility: The operating system release should be within the supported range.

    File system permissions: WebLogic Migration Tool is designed to be installed directly on to the AdminServer Host. An Operating System user with read and write permissions on WebLogic Domain's , Oracle Middleware and Java Home is require to perform tasks such us unzip, tar.

    Internet Connection: OWM Tool requires access to github.com repositories to download two required libraries - Weblogic Deployment Tool and JQ - to discover the source WebLogic environment. Alternatively, specific releases can be manually download and placed in $toolHome/deps/wdt and deps/jq respectively. 

    Network configuration: AdminServer Host must have an established SSH authentication system in place, connecting the AdminServer and all the Weblogic Managed server Linux hosts seamlessly.

    Storage Space:  Admin Server disk space to store 3 times the space used by Oracle Middleware and Oracle Domain home combined.

    Oracle Cloud Infrastructure CLI: The process of migrating an source on-premise WebLogic Domain involves compressing different directories and uploading them to an Oracle Cloud Object Storage Bucket. Current release uploads files using OCI cli.


*Oracle Cloud Requirements*

* Oracle Cloud Account (Tenancy) :  Resources discovered on-premise will be recreated under an OCI Tenancy.  

* OCI Compartment:  Oracle Cloud facilitates the organzation of resources using a logical separation called compartments.  A comparment is requred to group all the resources created by Oracle WebLogic Migration Tool.

* OCI Resource Manager:  Oracle Cloud Account with permissions to create, plan and apply Stacks.

* OCI Permissions:  Oracle CLoud user must have enough permissions to create, destroy, manage Virtual Cloud Network, Compute Instances, Block Storage, LoadBalancers, Private Resource Manager Endpoints.   

* Oracle CLI:  Details on how to install and configured can be found at https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm



Organization
-------------
**inputs** - this directory consists of following:
* **config/on-prem.env** - Weblogic Domain specific config

[//]: # (* **main.tf** - is where we call the modules in order as defined in ../oci/rm/.)

[//]: # (* **outputs.tf** - result printed on the stdout at the completion of terraform provisioning.)

[//]: # (* **provider.tf** - oci provider is defined.)


Installing OCI Weblogic Migration Tool
----------------------------------------
* Initiate a Secure Shell (SSH) connection to the AdminServer Linux Host, utilizing a user account with read and write file system permissions. This step enables secure remote access and interaction with the server.
* Download the most recent release from  https://github.com/oracle-quickstart/oci-weblogic-migration/releases
* Unzip the installer to a folder where the user has read and write permissions.
* Folder will be referenced as $OWM_HOME.


Install Pre-Requisites 
-----------------------
If the AdminServer host has access to internet OWM can automatically download and install WebLogic Deploy Tooling and JQ library from github repositories. 

$> bash install_dependencies.sh


Discover On-Premise WebLogic Domain
----------------------------------------

Step 1.  Declare WebLogic source domain details in $toolHome/config/on-prem.env

```bash
ssh_admin_server_host=           # Weblogic Server Admin IP or hostname.
ssh_user=                        # Operating system user with permissions to read
ssh_password_file=               #/path/to/file_with_ssh_password
ssh_private_key_file=            #/path/to/private_key_file

# [ SSH JumpHost]
ssh_jump_host=                     # Jumphost IP Address or hostname
ssh_jump_host_user=                # username to authenticate on SSH Jumphost
ssh_jump_host_password_file=       #/path/to/ssh_jump_host user password_file
ssh_jump_host_private_key_file=    #/path/to/ssh_jump_host user private_key_file

# [ HTTP Proxy]
http_proxy=                         #http proxy server address  i.e http://192.168.0.10:80
https_proxy=                        #https proxy server address  i.e https://192.168.0.10:80
http_proxy_user=                    #http proxy user
http_proxy_password_file=           #/path/to/https proxy_password file

# [ Weblogic Domain]
oracle_home=                     #set to ORACLE_HOME in local Linux Server.
jdk_home=                        # set to JDK path in local Linux Server.
node_manager_home=               # set the node_manager_home IF WebLogic Deployment Type is Node Manager per Machine. 
domain_home=                     # Path to WebLogic Domains: i.e /opt/domains/testdomain
wdt_home=./deps/wdt              # If Oracle WebLogic Deploy Tooling is already installed in the system.  Set WDT path  
```

### Step 2. Discover Weblogic Domain and generate Inventory 

In this step, OWM will read the on-prem.env configuration file and connect to the AdminServer host to discover the WebLogic domain.  If the task is successfull, it will generate a JSON formated file stored in $toolHome/out directory.   File name pattern is Discovery_<date>.json

From $OWM_HOME/bin directory run:
 
```bash
$>  bash owm.sh wls <on-prem.env>
```

###  Step 3.  Discover Infrastructure
A complete inventory file (json formated) will be created with entries found on the source WebLogic Domain and the infrastructure it is running on. The resulting file `infra_<date>.json` wil be stored at $OWM_HOME/out/ 

From $OWM_HOME/bin directory run:

```bash
$ bash owm.sh infra <on-prem.env> <PATH to Inventoryfile.json>
```

### Step 4.  Archive Weblogic Domain

In this step, each discovered machine found in the Complete Inventory file `_infra_<date>.json` will compress its own WebLogic Domain home, Jdk Home, Oracle Home and any custom directory found in the WebLogic configuration.  Each archive filename must follow the pattern weblogicMachineName_WebLogicDomainName_<folder_type>_home.tar.gz and stored under `$toolHome/out/<dir_specified>`

Note: All archives will be Secured Copied from each unique Host running Managed Servers to AdminServer host.  AdminServer Disk space must account for all of the files generated per Managed Server hosts

Note:  Is is highly recommended that the WebLogic Domain is in stop state before compressing directories to avoid files being modified between read and write. 

Example:

```bash
machinename1-testdomain-domain_home.tar.gz  
machinename1-testdomain-java_home.tar.gz  
machinename1-testdomain-weblogic_home.tar.gz
machinename1-testdomain-custom_home.tar.gz
```

From $OWM_HOME/bin directory run:

```bash
$ bash owm.sh archive <on-prem.env> -i <PATH to Complete Inventoryfile.json> -r <dir_name under $toolHome/out/> 
./owm.sh archive "$ONPREM_CONFIG" -i "$INFRA_DISCOVER" -r wls-coh
```

### Step 4.  Upload Archives to OCI Object Storage (Optional)

The restore process expects all of the archives to be stored in a Oracle Cloud Object Storage Bucket. Therefore, this steps helps with the upload process using the OCI cli client. 

To configure OCI CLI client and confirm that the OCI user has permissions to create Object Storage Buckets. More information at https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets_topic-To_create_a_bucket.htm#top

Note: User may opt to upload the archives manually due to Network security restrictions on-premise. Follow Oracle Cloud documentation on how to transfer files via the Oracle Cloud Console.

**Create OSS bucket and Upload Archives:**
```bash
$ owm.sh lift <on-prem config file> <PATH to InfraInventory File.json> <archive_dir> <bucket_name>
```
i.e  $> bash owm.sh lift ../config/on-prem.env ../out/inventory/infra_output_202410281306.json uat-files wlsmig_domain


### Step 4. Discovery Database Connections 

OWM will look for Datasources entires in the inventory file to identify JDBC datasources that need to be updated once the environment has been moved to OCI.  With the list of connection strings, it will generate a custom form that will let the user pick from their existing OCI ATP or Database to connect to. 

**Process Datasources**
```bash
$ bash owm.sh ds <on-prem.env> <PATH to Inventoryfile.json> 
```
i.e. ./owm.sh ds ../config/on-prem.env ../out/infra_output_202410281306.json

### Step 5.  Generate OCI Resource Manager Stack

Once all previous steps were correctly executed, the migration to OCI will happen via Resource Manager Service.  This step genarates a .zip file with a Infrastructure as Code files that will be the input to create a Resource Manager Stack in Oracle Cloud. 

```bash
$ bash owm.sh orm <PATH to `InfraInventory` File.json> 
```

i.e ./owm.sh orm ../out/infra_output_202410281306.json  will generate a stack named similar to owm_rm_202411042318.zip


Newly created Zip files will be stored under $OWM_HOME/oci/stack


### Step 5. Migrate WLS Domain to OCI Cloud

Resource Manager
--------------------

OCI Resource Manager requires the compress file created in section `Generate OCI Resource Manager Stack`. Transfer it to workstation that has access to OracleCloud from a Browser. 
Open a new Browser window/Tab and login into your OCI Tenancy. 
Once authenticated, select `Developer Services` from the list of OCI Services.(Top-Left corner)  
From the displayed dropdown, click on  `Developer Services`, select Stacks, then click on `Create Stack` button.
A `Create Stack` Wizard will be displayed. 
Under section `Stack Configuration`, select the option `.Zip file`.
Browse and Upload the Resource Manager stack file. Click Next.   
Customize any Stack variable that your environment requires or go with default. 
Then click create. 

From the Stack Details, click `Apply`. 

What it does
-------------

* Based on the variables value selected, Resource Manager will provision a number of OCI Compute Instances with the required OCI networking.
* User also has option to use pre-existing VCN. Network Security must be created along with the existing network. It should have internet gateway pre-configured.
* WebLogic Domains with JDBC Datasource configured can to select between Autonomous Database, Base System and Manual Datasource connection string replacement to recreate the Datasource connection string in OCI. 
* **Pre-requisites for JFR Weblogic enabled domains :**
  Databases should be migrated to OCI or accessible from OCI Cloud Compartment. JDBC String must be known before runing Resource Manager `Apply` action

* **Inputs to Resource Manager:**
    *  User will provide the following as param to terraform:
        * WLS Compartment name
        * WLS parameters
            * instance_shape
            * numVMInstances
            * SSH public key
        * Networking details
            * VCN Name (if creating new VCN)
            * VCN OCID (if using existing VCN)
            * wls_subnet_cidr (if using existing VCN)
            * Load Balancer CIDR (if new VCN)
        * Optional Load Balancer
            * add_load_balancer
        * Optional WLS private subnet
            * assign_backend_public_ip (defaults to true, false will create private subnet for WLS)
            * mgmt_subnet_cidr (Required for private subnet only if existing VCN is used)


    ** NOTE:** User will need to ensure the subnet CIDRs fit under new or existing VCN.

* **Provisioning flow** will be as follows:
    * **Create VCN (if not using existing)**
    * **Create Internet gateway(if not preconfigured), Route tables, and Network Security Group**
        * *Weblogic Network Security Group : AdminsServer and ManagedServer*
        * *Load balancer Network Security Group*
    * **Create Subnets**
        * Creates one or three subnets one in each Availabity Domains. Extra subnets are created if Load balancer and or bastion needs to be provisioned.
        * Configure Network Security (OCI Network Security Group) by opening specific ports discovered in the source environment.
    * **Create VM Instances**
        * During OCI Compute Instances boot process, init scripts will :
        * read the inventory file and download the archives in each Compute Instance
        * create Operating System user and groups with the same name discovered in the source environment.
        * create file systems and restore archives following the same directory tree found in the source environment.
        * The SSH Public key provided in the Stack Wizard will be configured in the user's home directory.
        
        * Assign NSGs wlsserver-nsg or adminserver-nsg to each OCI Instance depending on the type of Weblogic Server it hosts.
    * **Create Load balancer (if requested)**
        * If LB is being provisioned:
            * Create Loadbalancer
            * Create Loadbalancer listener for Managed Servers
            * Create Loadbalancer listener for Dynamic Servers Templates (if any)
            * Create Test Certificate on Port 443. 
            * Create BackendSet with WLS Managed Server Ports and Private IPs.
            * Create BackendSet with WLS Dynamic Server Template Listen Ports and OCI Instance private IPs. (if any) 
    * **Create Bastion Host (if requested)**
        * If Bastion is being provisioned:
            * Create Bastion Subnet
            * Create Bastion Network Security Groups
 

**Pre-requisites for supporting OCI DB as infrastructure DB:**
* User will configure the DB subnet's seclist with a secrule to open up 1521 port for VCN CIDR or new WLS subnet CIDR.
* Also user should have created an internet gateway in the VCN.

* **Inputs to terraform:**
    * User will provide the following as param to terraform in addtion to the WLS parameters listed above:
        * WLS Subnet CIDR
        * LB Frontend Subnet CIDR
        * LB Backend Subnet CIDR
        * Mgmt Subnet CIDR if using private subnet
        * DB's VCN Compartment Name
        * Number of WLS instances
        * OCI database Params:
            * db_connect_string (Optional if rest of parameters are provided)
            * db_hostname_prefix
            * db_host_domain
            * db_shape
            * db_version
            * db_name
            * db_unique_name
            * pdb_name
            * db_node_count (defaults to 1, required for Rac DB)
            * db_user
            * db_password

      **NOTE:** User will need to ensure the subnet CIDRs are subset of the DB VCN's CIDR.
* **Provisioning flow** will be as follows:
    * **Create a WLS security list** resource with rules:
        * Source: WLS Subnet CIDR, Destination Port: ALL
        * Source: 0.0.0.0/0, Destination Port: *WLS SSL Console Port*
    * **Create a WLS Subnet** with user specified CIDR in the user specified VCN and the new WLS security list.
    * If LB is being provisioned:
        * Create Security list for LB frontend subnet with following rule:
            * Source: 0.0.0.0/0, Destination port: 443
        * Create LB Frontend Subnet in user specified VCN and the new LB frontend security list.
        * Use the WLS Subnet created above for LB backend subnet.
        * Create backend set.
        * Create backend endpoints
        * Create LB resource.

* **Pre-requisites for supporting ATP DB as infrastructure DB:**
* User should download the wallet zip and provide the file path and wallet password as input to terraform.
* If using existing VCN, internet gateway has to pre-configured.

* **Inputs to terraform:**
    * User will provide the following as param to terraform in addtion to the WLS parameters listed above:
        * ATP database Params:
            * db_user ( defaults to ADMIN, as it cannot be changed in ATP)
            * db_password
            * db_name
            * atp_db_wallet_password
            * atp_db_wallet_path
            * atp_db_level
              Limitations
--------
* To use existing VCN, user needs to ensure that internet gateway is preconfigured.
* It can only support WLS and OCI DB in same VCN.


### Step 6. Start OCI WebLogic Domain and Verify Services

All OCI Instances (Servers hosting AdminServers and Managed Servers) will be created in a Private Subnet in OCI Virtual Cloud Network. To access them, an SSH session should be established via the Bastion Host created along this migration.  

To find the commands to ssh, click on Stack - Application Details Tab and copy the SSH command example given. 

The complete ssh command to access the AdminServer should follow this format:

```bash 
ssh -i <private ssh key file> -o 'UserKnownHostsFile /dev/null' -o 'StrictHostKeyChecking no' -o 'ProxyCommand ssh -W %h:%p -i <private ssh key file> -l opc <Bastion Public IP>' -l opc <AdminServer Private IP>

$admin-server> sudo su - <same username as on-premise> 
```

Once in the new AdminServer instance, change directory to the WebLogic Domain Home and bring up your AdminServer. Verify and Test your WebLogic domain to confirm that the migration was successful. 


