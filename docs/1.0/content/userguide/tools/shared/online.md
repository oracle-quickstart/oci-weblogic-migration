---
title: "Online operations"
date: 2023-12-22T09:36:00-05:00
draft: false
weight: 2
description: "Describes OWM tooling online behavior."
---

OCI Weblogic Migration supports online operations against running WebLogic Server-based domains.  By definition, this
means that OWM is acting as a remote client to the domain's admin server--even if the OWM tool is running on the same
machine as the admin server.  The main point being that OWM and the server may or may not be using the same Oracle Home.
This becomes an even more likely scenario when using the `-remote` option or when using SSH-based remote access.  This
document describes the general behavior you should expect when running OWM tools in online mode.

### Client and server Oracle Home version skew

OWM tools work best when OWM and WebLogic Server are running the same WebLogic Server version and patch levels.  Because
OWM uses WLST under the covers, some operations may not work properly when the effective WebLogic Server versions are not
aligned.  Prior to OWM 4.0, OWM tools use the local Oracle Home's WebLogic Server version to load its aliases (that is, 
knowledge base).  This means that in scenarios where OWM is using an older WebLogic Server version than the running
admin server, OWM would not have knowledge of or access to new configuration folders or attributes on the server.
For example, the Discover Domain Tool would simply skip over folders and attributes on the server than were not present
in the older WebLogic Server version being used by the OWM tool.  While this allowed some operations to complete without
any errors or warnings, the results are potentially incomplete or inaccurate.

Starting in OWM 4.0 with the introduction of SSH-based remote online operations, OWM now attempts to determine the
server version and patch level at tool startup.  If successful, OWM initializes the aliases using the server's version
instead of the version being used to run OWM.  This strategy allows OWM to access and use folders and attributes available
on the server.  For example, the Discover Domain tool can discover attributes on the server that may not exist in the
WebLogic Server version being used to run the tool.  However, this strategy also exposes OWM to version-skew related
issues, such as an MBean on the server that is not available in the WebLogic Server version being used by the OWM tool.
For example, the Discover Domain tool may now generate warnings like the one shown here.

```shell
        1. WLSDPLY-06140: Unable to cd to the expected path /RemoteConsoleHelper/mydomain constructed from location
context model_folders = ['RemoteConsoleHelper'],  'name_tokens' = {'REMOTECONSOLEHELPER': 'mydomain','DOMAIN': 'mydomain'};
the current folder and its sub-folders cannot be discovered: cd(/RemoteConsoleHelper/mydomain) in online mode failed:
Error cding to the MBean
```

Prior to OWM 4.0, this error should not have occurred because OWM was unaware of the `RemoteConsoleHelper` MBean, which
didn't exist in the WebLogic Server version being used to run the tool.  Discover Domain would simply have silently
skipped the discovery of this MBean and its configuration, resulting in an incomplete model.  With OWM 4.0, Discover
Domain will no longer silently skip server configuration and will warn you when it is unable to discover some aspects
of the server's configuration.  To rectify these warnings, simply make sure that OWM is using the same WebLogic Server
version and patch level as the running server.

### Domain name and home directory
Prior to OWM 4.0, online operations generally required the user to specify the path to the domain home directory.
Starting in OWM 4.0, online operations no longer require the user to specify the domain home directory.  Both the domain
name and home directory are determined using WLST online to interrogate the admin server to get the actual value from
the running server.  Any attempt to provide the `-domain_home` parameter to an online operation will result in a
notification message upon tool completion to let you know that the parameter was not used.
