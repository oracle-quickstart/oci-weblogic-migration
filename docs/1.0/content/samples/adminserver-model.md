---
title: "Administration Server in the Domain Model"
date: 2019-02-23T17:19:24-05:00
draft: false
weight: 1
description: "Administration Server in the domain model."
---

 ### Administration Server configuration

Oracle WebLogic Migration Tool attempts to discover the Administration Server based on the offline discover option in Oracle WebLogic Deploy Tool. An example of a discovered Admin Server is below. 
 ```yaml
 topology:
     Server:
         AdminServer:
             ListenPort: 9071
             RestartDelaySeconds: 10
             ListenAddress: my-host-1
             Log:
                 FileCount: 9
                 LogFileSeverity: Info
                 FileMinSize: 5000
             SSL:
                 HostnameVerificationIgnored: true
                 JSSEEnabled: true
                 ListenPort: 9072
                 Enabled: true
 ```

