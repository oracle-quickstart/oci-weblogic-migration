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
create_bastion=false
create_domain=false
#lb_max_bandwidth = 100
#lb_min_bandwidth = 100
bucket_name = "testdomain"
existing_load_balancer_id = null
wlsserver_block_volume_type     = "iscsi"
wlsserver_image_type = "Oracle WebLogic Server BYOL"
wlsserver_subnet_id = ""

