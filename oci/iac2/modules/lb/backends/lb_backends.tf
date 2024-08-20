# Copyright (c) 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

locals {
  /* count decides whether to provision load balancer */
  use_https_listener_count = !var.use_existing_lb ? 1 : 0
  health_check_url_path    = var.health_check_url
}

resource "oci_load_balancer_backend_set" "wls_lb_backendset" {
  # If using existing load balancer, use per-created backend set of existing lb
  count = var.use_existing_lb ? 0 : 1

  name             = var.lb_backendset_name
  load_balancer_id = var.load_balancer_id
  policy           = var.lb_policy

  health_checker {
    #TODO: JOI : Review what will be the backend_port when dynamic servers are present
    port                = var.backend_port
    protocol            = var.lb_protocol
    response_body_regex = ".*"
    url_path            = local.health_check_url_path
    return_code         = var.return_code
  }

  # Set the session persistence to lb-session-persistence with all default values.
  lb_cookie_session_persistence_configuration {}
}


resource "oci_load_balancer_listener" "wls_lb_listener_https" {
  count                    = local.use_https_listener_count
  load_balancer_id         = var.load_balancer_id
  name                     = format("%s-%v_https", var.resource_name_prefix, var.state_id)
  default_backend_set_name = var.use_existing_lb ? var.lb_backendset_name : oci_load_balancer_backend_set.wls_lb_backendset[count.index].name
  port                     = var.lb_https_lstr_port
  protocol                 = var.lb_protocol
  rule_set_names           = [oci_load_balancer_rule_set.SSL_headers[count.index].name]

  connection_configuration {
    idle_timeout_in_seconds = "10"
  }
  ssl_configuration {
    #Required
    certificate_name        = oci_load_balancer_certificate.demo_certificate[count.index].certificate_name
    verify_peer_certificate = false
  }

  lifecycle {
    ignore_changes = [ssl_configuration]
  }
}
 #list of IPs (OCI instances) and a list of Ports per OCI Instance.
resource "oci_load_balancer_backend" "wls_lb_backend" {
#  count = var.use_existing_lb || (length(oci_load_balancer_backend_set.wls_lb_backendset) > 0) ? var.num_vm_instances : 0
  for_each = var.backend_instance_ports
  load_balancer_id = var.load_balancer_id #oci_load_balancer.wls_lb.id
  backendset_name  = var.use_existing_lb ? var.lb_backendset_name : oci_load_balancer_backend_set.wls_lb_backendset[0].name
  ip_address       = each.value[0].instance #var.instance_private_ips[count.index]
  port             = each.value[0].port #var.backend_port
  backup           = false
  drain            = false
  offline          = false
  weight           = var.policy_weight

  lifecycle {
    ignore_changes = [offline]
  }
}

resource "oci_load_balancer_rule_set" "SSL_headers" {
  count = local.use_https_listener_count

  load_balancer_id = var.load_balancer_id
  name             = "${var.resource_name_prefix}_SSLHeaders"
  items {
    action = "ADD_HTTP_REQUEST_HEADER"
    header = "WL-Proxy-SSL"
    value  = "true"
  }
  items {
    action = "ADD_HTTP_REQUEST_HEADER"
    header = "is_ssl"
    value  = "ssl"
  }
}
