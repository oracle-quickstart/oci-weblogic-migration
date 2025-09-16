# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      configuration_aliases = [oci.home]
      source                = "oracle/oci"
#      version               = ">= 4.119.0"
      version               = ">= 6.6.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.3"
    }
    template = {
      version = "~>2.2.0"
    }
    tls = {
      version = "~>4.0.3"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
  }
}
