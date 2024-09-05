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
pub_lb_nsg_id = "ocid1.networksecuritygroup.oc1.iad.aaaaaaaap4yeoghjd5hdhfytyltix3fcytkfrbmdmvu5btkate2iczucqvta"
pub_lb_subnet_id = "ocid1.subnet.oc1.iad.aaaaaaaabnfuwogcnat3bhpumnv34niqaa4d4hnxuwnmxlvhxv6irjonubea"
ssh_kms_secret_id = "ocid1.vaultsecret.oc1.iad.amaaaaaadoggtjaacge2rlm7z6d54xo5cvtlo26mrptgzubena6obxfhuihq"
create_bastion=false
create_domain=false
lb_max_bandwidth = 100
lb_min_bandwidth = 100
bucket_name = "testdomain"
existing_load_balancer_id = null
custom_backends=["192.168.0.1","10.0.111.149"]
load_balancer_shape = "100Mbps"
wlsserver_block_volume_type     = "iscsi"
wlsserver_image_type = "Oracle WebLogic Server BYOL"
wlsserver_subnet_id = ""

