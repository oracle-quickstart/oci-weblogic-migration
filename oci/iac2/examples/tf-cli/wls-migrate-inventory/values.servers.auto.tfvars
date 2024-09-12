#bastion_public_ip = "129.213.96.178"
ssh_kms_secret_id = "ocid1.vaultsecret.oc1.iad.amaaaaaadoggtjaacge2rlm7z6d54xo5cvtlo26mrptgzubena6obxfhuihq"
wlsserver_block_volume_type     = "iscsi"
wlsserver_image_type = "Oracle WebLogic Server BYOL"
create_domain=true
allow_wlsserver_ssh_access = true   # connection from bastion to managed server
allow_adminserver_ssh_access = true  # connection from bastion to admin server  (if admin and managed nsgs are both in the same host and allow_wlsserver_ssh_access is true but allow_adminserver_ssh_access is false. Access wont be granted. same if opposite)
wlsserver_cloud_init_configure = false # No cloud_init customize