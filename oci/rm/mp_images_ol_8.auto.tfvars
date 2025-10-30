# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

#TODO: mp_images_ol.auto.tfvars is generated from build_orm
# If inventory detected OL/RHEL 7,  Values of images bellow is updated to Weblogic Marketplace Images (mp_images_ol_7.auto.tfvars).
# If inventory detected OL/RHEL 8,  Values of images bellow is updated to Weblogic Marketplace Images (mp_images_ol_8.auto.tfvars).

tf_script_version        = "25.4.1-251024040114"
#[Enterprise BYOL]
byol_listing_id               = "ocid1.appcataloglisting.oc1..aaaaaaaawd5ti5ldjzdppppi675onvo3mvjcwt64jjey7rib3beau2ngkl2q"
byol_listing_resource_version = "25.4.1-ol8.8-23.12.13-251024-1"
byol_instance_image_id        = "ocid1.image.oc1..aaaaaaaajtldbwdlrovciafil4vjkcfkp26qpnpuajyyiphnmitfuo2ix6la"
#[Suite BYOL]
suite_byol_listing_id               = "ocid1.appcataloglisting.oc1..aaaaaaaajl5w3d76x5vdc4n7oqjpsxh4jtwivclvvp6gj4em3kufju6sftga"
suite_byol_listing_resource_version = "25.4.1-ol8.8-23.12.13-251024-1"
suite_byol_instance_image_id        = "ocid1.image.oc1..aaaaaaaad555thklryolvtso5y7pw67kuzzhz23qwiowuczuhwiwhgtc3xrq"
#[Enterprise UCM]
ucm_listing_id               = "ocid1.appcataloglisting.oc1..aaaaaaaa653zc2e4fsem5hhwinmfgnv3xp4dmbq6c6gvf45okxf6xz3smhiq"
ucm_listing_resource_version = "25.4.1-ol8.8-23.12.13-251024-1"
ucm_instance_image_id        = "ocid1.image.oc1..aaaaaaaanptrtarff3qsf46hhy37j66jl7mps227t65ur2vu2msjbxoye2ba"
#[Suite UCM]
suite_ucm_listing_id       = "ocid1.appcataloglisting.oc1..aaaaaaaaq2vkow7zwkxg6ky4zxsnckdlfgtgmg7i4kkyev3y6zyo72mpkgza"
suite_ucm_listing_resource_version = "25.4.1-ol8.8-23.12.13-251024-1"
suite_ucm_instance_image_id    = "ocid1.image.oc1..aaaaaaaag7grvrv2xnjuiulzx4hotcdx77ljdfmgojjiiyh4vjah6ozg5mba"

#instance_image_id = custom or platform image_id and use_marketplace_image=false

