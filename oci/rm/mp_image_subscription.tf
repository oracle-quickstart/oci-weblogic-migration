# Copyright (c) 2028 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.


#Get EE BYOL Image Agreement
resource "oci_core_app_catalog_listing_resource_version_agreement" "wls_mp_byol_image_agreement" {
  count                    = var.use_marketplace_image ? 1 : 0
  listing_id               = var.byol_listing_id
  listing_resource_version = var.byol_listing_resource_version
}

#Accept Terms and Subscribe to the image, placing the image in a particular compartment BYOL
resource "oci_core_app_catalog_subscription" "wls_mp_byol_image_subscription" {
  count                    = var.use_marketplace_image ? 1 : 0
  compartment_id           = var.compartment_ocid
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_byol_image_agreement[0].eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_byol_image_agreement[0].listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_byol_image_agreement[0].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_byol_image_agreement[0].oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_byol_image_agreement[0].signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_byol_image_agreement[0].time_retrieved

  timeouts {
    create = "20m"
  }
}

#Get SUITE BYOL Image Agreement
resource "oci_core_app_catalog_listing_resource_version_agreement" "wls_mp_suite_byol_image_agreement" {
  count                    = var.use_marketplace_image ? 1 : 0
  listing_id               = var.suite_byol_listing_id
  listing_resource_version = var.suite_byol_listing_resource_version
}

#Accept Terms and Subscribe to the image, placing the image in a particular compartment BYOL
resource "oci_core_app_catalog_subscription" "wls_mp_suite_byol_image_subscription" {
  count                    = var.use_marketplace_image ? 1 : 0
  compartment_id           = var.compartment_ocid
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_byol_image_agreement[0].eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_byol_image_agreement[0].listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_byol_image_agreement[0].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_byol_image_agreement[0].oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_byol_image_agreement[0].signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_byol_image_agreement[0].time_retrieved

  timeouts {
    create = "20m"
  }
}

##Subscribe to the EE UCM market place image only from BYOL bundles
resource "oci_core_app_catalog_listing_resource_version_agreement" "wls_mp_ucm_image_agreement" {
  count                    = var.use_marketplace_image && var.terms_and_conditions ? 1 : 0
  listing_id               = var.ucm_listing_id
  listing_resource_version = var.ucm_listing_resource_version
}

#Accept Terms and Subscribe to the image, placing the image in a particular compartment - EE
resource "oci_core_app_catalog_subscription" "wls_mp_ucm_image_subscription" {
  count                    = var.use_marketplace_image && var.terms_and_conditions ? 1 : 0
  compartment_id           = var.compartment_ocid
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_ucm_image_agreement[0].eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_ucm_image_agreement[0].listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_ucm_image_agreement[0].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_ucm_image_agreement[0].oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_ucm_image_agreement[0].signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_ucm_image_agreement[0].time_retrieved

  timeouts {
    create = "20m"
  }
}

# SUITE
resource "oci_core_app_catalog_listing_resource_version_agreement" "wls_mp_suite_ucm_image_agreement" {
  count                    = var.use_marketplace_image && var.terms_and_conditions ? 1 : 0
  listing_id               = var.suite_ucm_listing_id
  listing_resource_version = var.suite_ucm_listing_resource_version
}

#Accept Terms and Subscribe to the image, placing the image in a particular compartment - SUITE
resource "oci_core_app_catalog_subscription" "wls_mp_suite_ucm_image_subscription" {
  count                    = var.use_marketplace_image && var.terms_and_conditions ? 1 : 0
  compartment_id           = var.compartment_ocid
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_ucm_image_agreement[0].eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_ucm_image_agreement[0].listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_ucm_image_agreement[0].listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_ucm_image_agreement[0].oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_ucm_image_agreement[0].signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.wls_mp_suite_ucm_image_agreement[0].time_retrieved

  timeouts {
    create = "20m"
  }
}
