---
title: "Limitations"
date: 2024-10-02T13:35:38-05:00
draft: false
weight: 7
description: "Review existing OWM limitations."
---


The following sections describe known limitations for OCI Weblogic Migration. Each issue may contain a workaround or an associated issue number.

### OCI Resource Manager -  

**ISSUE**: OCI Resource Manager Stack Filed error :
```
Specify a value that satisfies the following regular expression: ^ocid1.image.*$ .
```

**ACTION**: 
OCI Resource Manager will attempt to re-populate Image dropdown.  Select a different Shape and a compatible OCI Image.  


#### Discover Domain Tool `SEVERE` messages

**ISSUE**:
The `discoverDomain` STDOUT contains many SEVERE messages about `cd()` and `ls()` when it is run against a 12.2.1.0
domain. The Discover Domain Tool navigates through the domain MBeans using WLST to determine which MBeans are present
in a domain. When it tests an MBean that is not present, an error message is logged by WLST. There is no 12.2.1.0 PSU
available to address this WLST problem. It is resolved in 12.2.1.1.

**ACTION**:
Ignore the following messages logged during discovery of a 12.2.1.0 domain.
```
<Jan 14, 2019 1:14:21 PM> <SEVERE> <CommandExceptionHandler> <handleException> <> <Error: cd() failed.>
<Jan 14, 2019 1:14:21 PM> <SEVERE> <CommandExceptionHandler> <handleException> <> <Error: ls() failed.>
```

#### Credential in security configuration

**ISSUE**: For WLS versions prior to 14.1.1, there is a problem setting the `CredentialEncrypted` attribute in the
`topology/SecurityConfiguration` folder. The value is not encrypted properly in the configuration and the domain will
fail to start with the error:
```
java.lang.IllegalArgumentException: In production mode, it's not allowed to set a clear text value to the property: CredentialEncrypted of SecurityConfigurationMBean
```
**ACTION**: Contact Oracle Support to obtain the patch for bug number 30874677 for your WebLogic Server version before running the tool.

#### Problems setting `RotateLogOnStartup` attribute

**ISSUE**: For existing WLS versions, there is a problem setting the `RotateLogOnStartup` attribute in various log file
folders. The value is not persisted correctly, and the assignment will not be present when the domain is started.

**ACTION**: Contact Oracle Support to obtain the patch for bug number 29547985 for your WebLogic Server version before running the tool.

#### Discover Domain tool does not discover users or groups

**ISSUE**: Discovering a domain does not attempt to discover users and groups defined in any configured Authentication Provider type.

**ACTION**: This should only be an issue for the domains using the DefaultAuthenticator, which uses the Embedded LDAP
server that runs inside WebLogic Server as its user and group store.  To discover the users and groups in the
DefaultAuthenticator, use the `-discover_security_provider_data` switch with an argument that includes the
DefaultAuthenticator (e.g., `ALL` or a comma-separated list of provider types like `DefaultAuthenticator,DefaultCredentialMapper`).
