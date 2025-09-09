+++
title = "Release Notes"
date = 2024-01-09T18:27:38-05:00
weight = 70
pre = "<b> </b>"
+++


### Changes in Release 1.1.0
- [Major New Features](#major-new-features)
- [Other Changes](#other-changes)
- [Bugs Fixes](#bug-fixes)
- [Known Issues](#known-issues)


#### Major New Features
None

#### Other Changes
None

#### Bug Fixes
None

#### Known Issues
- SSH support requires a reasonably recent version of Bouncy Castle.  OWM picks up Bouncy Castle from WLST so, for example,
  the 12.2.1.4.0 GA release fails with the following error, as mentioned at https://github.com/hierynomus/sshj/issues/895.
  Applying a recent PSU should resolve the issue for 12.2.1.4 and 14.1.1.

  ```shell
  SEVERE Messages:
          1. WLSDPLY-20008: verifySSH argument processing failed: Failed to initialize SSH context: Failed to SSH connect to host myhost.oracle.com: no such algorithm: X25519 for provider BC
  ```

- SSH support for the Update Domain Tool and Deploy Apps Tool does not work when using an archive file and the remote 
  WebLogic Server is running on Windows using the optional, Windows-provided, OpenSSH component.  This is due to an
  issue with the SSHJ library OWM is using.  See https://github.com/hierynomus/sshj/issues/929 for more information.

See https://oracle.github.io/oci-weblogic-migration/userguide/limitations/limitations/ for the current set of known limitations.
