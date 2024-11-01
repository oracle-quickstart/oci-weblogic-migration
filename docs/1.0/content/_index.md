## OCI Weblogic Migration

OCI Weblogic Migration (OWM) tool is designed to Lift and Shift WebLogic environments to Oracle Cloud Infrastructure 

OCI Weblogic Migration automates the process to discover a existing Weblogic Domain configuration running on Linux Environments. It creates specific archives with the contents of Java Home, Oracle Middleware Home, Oracle Weblogic Domain Home and custom to directories. Archives are Stored in OCI Object Storage Service for future usage.    
The tool creates an OCI Resource Manager Infrastructure as Code Stack to automate the creation of OCI resources in Oracle Cloud. 
While moving your source environment to Oracle Cloud it lets you specify simple mutations suitable for moving your model between different environments, such as between test and production.

OWM provides several single-purpose tools, all exposed as shell scripts (for LINUX), that can:

* Discover Weblogic Domain.  
* Populate a domain with all the resources and applications specified in a model.
* Discover Linux Operating System Network configurations.
* Generate archives with Weblogic Domain specific folder contents.
* Upload Archives to Oracle Cloud Infrastructure Object Storage Buckets. 
* Generate OCI Resource Manager Stacks to move Weblogic Domains in OCI Comparments.

For detailed information, see [OWM Tools]({{< relref "/userguide/tools/" >}}).

***
### Current production release

OCI Weblogic Migration version and release information can be found [here](https://github.com/oracle/oci-weblogic-migration/releases).

***
### Recent changes and known issues

See the [Release Notes]({{< relref "/release-notes.md" >}}) for known issues and workarounds.

### About this documentation

This documentation includes sections targeted to different audiences:

* [Concepts]({{< relref "/concepts/" >}}) explains the underlying metadata models and archive files.
* The [User Guide]({{< relref "/userguide/" >}}) contains detailed usage information, including how to install and configure OCI Weblogic Migration, and how to use each tool.
[//]: # (* The [Samples]&#40;{{< relref "/samples/" >}}&#41; provide informative use case scenarios.)
[//]: # (* The [Developer Guide]&#40;{{< relref "/developer/" >}}&#41; provides details for people who) want to understand how OWM is built, its features mapped and implemented. Those who wish to contribute to the OCI Weblogic Migration code will find useful information [here]({{< relref "/developer/contribute.md" >}}).

### Related projects
* [WebLogic Deployment Tool](https://oracle.github.io/weblogic-deploy-tooling)
* [WebLogic Kubernetes Operator](https://oracle.github.io/weblogic-kubernetes-operator/)
* [WebLogic Image Tool](https://oracle.github.io/weblogic-image-tool/)
* [WebLogic Kubernetes Toolkit UI](https://oracle.github.io/weblogic-toolkit-ui/)
* [WebLogic Monitoring Exporter](https://github.com/oracle/weblogic-monitoring-exporter)
* [WebLogic Logging Exporter](https://github.com/oracle/weblogic-logging-exporter)
* [WebLogic Remote Console](https://oracle.github.io/weblogic-remote-console/)
