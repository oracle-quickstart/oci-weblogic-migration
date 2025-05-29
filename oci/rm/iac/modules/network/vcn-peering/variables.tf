variable "db_existing_vcn_id" {
  type        = string
  description = "The OCID of the VCN used by the ATP database private endpoint"
}

variable "db_network_compartment_id" {
  type        = string
  description = "The OCID of the compartment in which the DB System VCN is found"
}

variable "compartment_id" {
  description = "The compartment id where network resources will be created."
  type        = string
}

variable "vcn_id" {
  description = "Optional ID of existing VCN. Takes priority over vcn_name filter. Ignored when `create_vcn = true`."
  type        = string
}

variable "wls_existing_vcn_id" { type = string }
variable "wlsserver_subnet_id" { type = string }


variable "db_subnet_id" {
  type        = string
  description = "The OCID of the subnet for the OCI DB or ATP DB (when using private endpoint)"
}