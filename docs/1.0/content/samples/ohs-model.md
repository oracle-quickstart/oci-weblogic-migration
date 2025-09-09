---
title: "Configuring Oracle HTTP Server"
date: 2019-02-23T17:19:24-05:00
draft: false
weight: 9
description: "A model for configuring Oracle HTTP Server (OHS)."
---

The OHS template must be present in the OWM domain type definition file used to create or update the domain. For more information on creating a custom definition, see [Domain type definitions]({{< relref "/userguide/tools-config/domain_def.md" >}}).


#### Discovering OHS model

Discovering a OHS typically involves adding two top-level folders to the `resources` section of the model, `SystemComponent` and `OHS`. Here is an example:
```yaml
resources:
    SystemComponent:
        my-ohs:
            ComponentType: OHS
            Machine: my-machine
    OHS:
        my-ohs:
            AdminHost: 127.0.0.1
            AdminPort: 9324
            ListenAddress: 127.0.0.1
            ListenPort: 7323
            SSLListenPort: 4323
            ServerName: http://localhost:7323
```
Each name under the `OHS` folder must match a name under the `SystemComponent` folder in the model, or the name of a `SystemComponent` element that has been previously created. In this example, the name `my-ohs` is in both places.

The `ComponentType` field of the `SystemComponent` element must be set to `OHS` in order to allow configuration of the corresponding `OHS` folders.

You can use the [Model Help Tool]({{< relref "/userguide/tools/model_help.md" >}}) to determine the complete list of folders and attributes that can be used in these sections of the model. For example, this command will list the attributes in the `OHS` folder:
```bash
$ ${OWM_HOME}/bin/modelHelp.sh -oracle_home /tmp/oracle resources:/OHS
```
