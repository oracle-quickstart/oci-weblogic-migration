locals {

}
resource "time_sleep" "wait_for_wls_vcn_dns_resolver" {
  create_duration = "20s"
}

resource "oci_core_local_peering_gateway" "dblpg_0" {
  #Required
  compartment_id = var.db_network_compartment_id
  display_name   = "dblpg_0"
  vcn_id = var.db_existing_vcn_id
}

resource "oci_core_local_peering_gateway" "wlslpg_0" {
  #Required
  depends_on = [time_sleep.wait_for_wls_vcn_dns_resolver]
  compartment_id = var.compartment_id
  display_name   = "wlslpg_0"
  vcn_id = var.vcn_id
  peer_id = oci_core_local_peering_gateway.dblpg_0.id
}