# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "tls_private_key" "opc_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "bastion_opc_key" {
  count = var.create_bastion ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}