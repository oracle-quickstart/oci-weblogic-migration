# Copyright (c) 2025 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "null_resource" "await_cloudinit" {
  for_each = oci_core_instance.wlsservers

  depends_on = [oci_core_instance.wlsservers]

  connection {
    type        = "ssh"
    user        = "opc"
    timeout     = "30m"
    private_key = var.opc_key["private_key_pem"]
    host        = var.create_bastion ? each.value.private_ip : data.oci_resourcemanager_private_endpoint_reachable_ip.private_endpoint_reachable_ips[each.key].ip_address

    bastion_host        = var.bastion_host_ip
    bastion_user        = "opc"
    bastion_private_key = var.bastion_host_private_key
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOF
    set -e
    if cloud-init status --wait; then
      echo "cloud-init completed successfully on the host: $(hostname)"
    else
      echo "======= Cloud-init Error Summary of the host: $(hostname) ======="
      awk '
        /<ERROR>|Traceback|Exception/ { print_line = 1 }
        print_line { print }
        /^$|^.*INFO.*$|^.*DEBUG.*$/ { print_line = 0 }
      ' /var/log/cloud-init-output.log | tail -n 150 || echo "No errors found."
      echo -e "\nRefer to /var/log/cloud-init-output.log and /var/log/owm/*.log for more details."
      echo "======= End of Error Summary of the host: $(hostname) ======="
      exit 1
    fi
    EOF
    ]
  }
}