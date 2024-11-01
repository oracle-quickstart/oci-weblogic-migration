Purpose
-------
This solution lifts and shifts single/multi node Weblogic cluster to Oracle Cloud Infrastructure optionally fronted
by a load balancer. The solution will create only one stack at time and further modifications that are done will be
done on the same stack.




**On-Premise Requirements**
Oracle Linux compatible Operating Systems releases.  
User with read and write file system permissions to unzip, create directories in AdminServer Linux Server host.
Access to download Weblogic Deployment Tool, JQ. from github repositories directly from AdminServer Linux Host.
AdminServer Host must have pre-configured ssh authentication between AdminServer and all the Weblogic Managed server Linux hosts.
Oracle Cloud Infrastructure CLI installed. 


**Public subnet Topology**
Creates following subnets under new VCN or existing VCN in different ADs.
* Loadbalancer Frontend Public Subnet


**Private Subnet Topology**
Creates following subnets under new VCN or existing VCN in different ADs.

* WLS Private Subnet
* Management Public Subnet (for bastion host)
* Loadbalancer Frontend Public Subnet


Organization
-------------
**inputs** - this directory consists of following:
* **config/on-prem.env** - Weblogic Domain specific config

[//]: # (* **main.tf** - is where we call the modules in order as defined in ../oci/iac/.)

[//]: # (* **outputs.tf** - result printed on the stdout at the completion of terraform provisioning.)

[//]: # (* **provider.tf** - oci provider is defined.)

OCI Pre-requisites
--------------------
The OCI CLI supports API Key based authentication and Instance Principal based authentication. Details on how to install and configured can be found at https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm

**Tenancy OCID** - The global identifier for your account, always shown on the bottom of the web console.
**User OCID** - The identifier of the user account you will be using for Terraform
**Fingerprint** - The fingerprint of the public key added in the above user's API Keys section of the web console.
**Private key path** - The path to the private key stored on your computer. The public key portion must be added to the user account above in the API Keys section of the web console.

Installing OCI Weblogic Migration Tool
----------------------------------------
Open a Secure SHell (SSH) session to AdminServer linux host. 
Download the most recent release from  https://github.com/oracle-quickstart/oci-weblogic-migration/releases
Unzip the installer to a folder where the user has read and write permissions. 
Folder is now will be referenced as $OWM_HOME   

To invoke OCI Weblogic Migration Tool
----------------------------------------
Before running any script, make sure a configuration file is correctly populated in $OWM_HOME/config. Use on-prem.env as a reference. 

From $OWM_HOME/bin dir execute:

### Discover Weblogic Domain and Generate Inventory 
```bash
$ owm.sh local <on-prem.env>
```

### Discover Infrastructure
Default path to Inventory File in json format is $OWM_HOME/out/ 
```bash
$ owm.sh local <on-prem.env> <PATH to Inventoryfile.json>
```

### Archive Weblogic Domain
Default path to `Inventory File` is $OWM_HOME/out/.

**WLS Non JRF:**
If the domain to be discovered is a JRF type domain. Do not set any value to property `wls_domain_type` in the environment config file
**WLS JRF with Database:**
If the domain to be discovered is a JRF type domain. Set the property `wls_domain_type=JRF` in the environment config file

```bash
$ owm.sh archive <on-prem.env> <PATH to Inventoryfile.json> <PATH to `InfraInventory` File.json> 
```

### Upload Archives to OCI Object Storage
Configure OCI CLI client and confirm that the OCI user has permissions to create Object Storage Buckets.
More information at https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/managingbuckets_topic-To_create_a_bucket.htm#top
**Create OSS bucket and Upload Archives:**
```bash
$ owm.sh lift <on-prem.env> <PATH to `WLSInventory` File.json> <PATH to `InfraInventory` File.json>
```

### Database Connections Inventory
OWM can inspect your domain to identify JDBC datasources that need to be updated once the environment has been moved to OCI.  

**Process Datasources**
```bash
$ owm.sh ds <PATH to Inventoryfile.json>
```

### Generate OCI Resource Manager Stack
Once you confirmed the Inventory Files were correctly created with the Weblogic Domain to be moved to OCI. Proceed to create an OCI Resource Manager Stack.
```bash
$ owm.sh orm <stack_name> <PATH to `InfraInventory` File.json>
```
Newly created OCI Resource Manager Stack will be created under $OWM_HOME/oci/stack


### Move WLS Domain to OCI Cloud

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

**Pre-requisites for JFR Weblogic enabled domains :**
Databases should be migrated to OCI or accessible from OCI Cloud Compartment. JDBC String must be known before runing Resource Manager `Apply` action  


* Based on the variables value selected, Resource Manager will provision a number of OCI Compute Instances with the required OCI networking.
* User also has option to use pre-existing VCN. Network Security must be created along with the existing network. It should have internet gateway pre-configured.

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

Tests
-----
https://coherence.us.oracle.com/display/CLOUD/WLS+Terraform+Testing - documents all test cases.