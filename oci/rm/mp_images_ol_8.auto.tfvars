# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

#TODO: mp_images_ol.auto.tfvars is generated from build_orm
# If inventory detected OL/RHEL 7,  Values of images bellow is updated to Weblogic Marketplace Images (mp_images_ol_7.auto.tfvars).
# If inventory detected OL/RHEL 8,  Values of images bellow is updated to Weblogic Marketplace Images (mp_images_ol_8.auto.tfvars).

tf_script_version        = "24.3.2-240826233830"
#[BYOL]
listing_id               = "ocid1.appcataloglisting.oc1..aaaaaaaaq2vkow7zwkxg6ky4zxsnckdlfgtgmg7i4kkyev3y6zyo72mpkgza"
listing_resource_version = "24.3.2-ol8.8-23.12.13-240826-1"
instance_image_id        = "ocid1.image.oc1..aaaaaaaauu7t5rihkowgsfimkdqrlyg46w24ri2bae4bgvsypbemhcewe6eq"
#[Enterprise UCM]
ucm_listing_id               = "ocid1.appcataloglisting.oc1..aaaaaaaa653zc2e4fsem5hhwinmfgnv3xp4dmbq6c6gvf45okxf6xz3smhiq"
ucm_listing_resource_version = "24.3.2-ol8.8-23.12.13-240826-1"
ucm_instance_image_id        = "ocid1.image.oc1..aaaaaaaasbest4ysvkitc6bp27klwflg3zfbz5hb637htezsovaqivkk72qa"
#[Suite UCM]
suite_ucm_listing_id       = "ocid1.appcataloglisting.oc1..aaaaaaaaq2vkow7zwkxg6ky4zxsnckdlfgtgmg7i4kkyev3y6zyo72mpkgza"
suite_ucm_listing_resource_version = "24.4.1-ol8.8-23.12.13-241017-1"
suite_ucm_instance_image_id    = "ocid1.image.oc1..aaaaaaaaruq5xvtwyn3g63kuzf2wyuwonyyxsibqf3ojmtuyphx2lu6g7gdq"

#instance_image_id = custom or platform image_id and use_marketplace_image=false

