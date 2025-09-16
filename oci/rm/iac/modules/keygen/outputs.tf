# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

output "opc_keys" {
  value       = tomap({ "public_key_openssh" = tls_private_key.opc_key.public_key_openssh, "private_key_pem" = tls_private_key.opc_key.private_key_pem })
  description = "A map with the public and private key (in pem format) generated for the opc user"
}

output "bastion_private_key" {
  value = var.create_bastion ? try(tls_private_key.bastion_opc_key[0].private_key_pem, "") : null
}

output "bastion_public_key" {
  value = var.create_bastion ? try(tls_private_key.bastion_opc_key[0].public_key_openssh, "") : null
}