# Copyright (c) 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

wlsserver_pools = {
##  managedserver-vm-instance = {
##    description = "Managed Instances",
##    mode        = "instance",
##    size        = 1,
###    node_labels = {
###      "role" = "wlsserver",
###      "domain" = "testdomain",
###      "type" = "managedservers"
###    },
##    secondary_vnics = {
##      "vnic-display-name" = {},
##    },
##  },
#  adminserver-vm-instance = {
#    description = "AdminServer Instance",
#    mode        = "instance",
#    size        = 1,
##    node_labels = {
##      "role" = "wlsserver",
##      "domain" = "testdomain",
##      "type" = "adminserver"
##    },
#    secondary_vnics = {
#      "vnic-display-name" = {},
#    },
#  },
}
vcn_id="ocid1.vcn.oc1.iad.amaaaaaadoggtjaaqfwhkrsz3xrnexcypypm4rsdirq36ur6zisxoulhcf6a"
state_id = "paymxu"
managedserver_nsg_id = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaasbjpcx57kxee5nsxxkpszahegcu6art6try5tpi5yqul6pp6acaa"
adminserver_nsg_id = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaatcjfgxnfqjbfqpmmmebkfncmwb4efmvegwlod7byfbfq3mtzeqhq"
wlsserver_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaadehg4ndpgnp7gjo4oqoubmfcihn5wu7xcmwpakodgzetp47mgmha"
#bastion_nsg_id = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaah5yfj46lo4ffptkz6orycbevwunadioedw5pgzoo6dwrgocnjzra"
bastion_nsg_id = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaasbjpcx57kxee5nsxxkpszahegcu6art6try5tpi5yqul6pp6acaa"
bastion_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaadehg4ndpgnp7gjo4oqoubmfcihn5wu7xcmwpakodgzetp47mgmha"
bastion_public_ip = "129.213.96.178"
ssh_kms_secret_id = "ocid1.vaultsecret.oc1.iad.amaaaaaadoggtjaacge2rlm7z6d54xo5cvtlo26mrptgzubena6obxfhuihq"
create_bastion=false
wlsserver_block_volume_type     = "iscsi"
wlsserver_image_type = "Oracle WebLogic Server BYOL"
#wlsserver_pool_name ="testdomain"
create_domain=true
bucket_name = "testdomain"