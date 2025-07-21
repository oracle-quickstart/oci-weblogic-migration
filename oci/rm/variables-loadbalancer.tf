# LoadBalancer

variable "create_demo_certificate" {default = false}
variable "load_balancer_shape" {
  default = "100Mbps"  #TODO: JOI : remove and set to flexible
}
variable "lb_max_bandwidth" {
  default = "100"
}
variable "lb_min_bandwidth" {
  default = "10"
}
variable "existing_load_balancer_id" {
  type= string
  default = null
}
variable "custom_backends" {
  type=list(string)
  default = []
}

variable "use_existing_loadbalancer" {
  default = false
}