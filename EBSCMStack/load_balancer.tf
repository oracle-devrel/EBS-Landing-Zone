# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.

# inputs

variable "generate_cert" {
    type = bool 
    default = false 
    description = "currently not supported"
}

variable "cm_ca_cert" {
  # type = string
  default = null
}


variable "cm_public_cert" {
    # type = string # TODO what var type should be used for RM files
    default = null
}


variable "cm_key_cert" {
    # type = string 
    default = null
}

variable "private_lb_ip" {
  type = bool
  default = true
}


/* expected defined values 
local.cm_hostname - string
local.cm_lb_snet_id - string

*/


# outputs

locals {
  lb_ip = oci_load_balancer_load_balancer.ebscm.ip_address_details[0].ip_address
  lb_id = oci_load_balancer_load_balancer.ebscm.id
  hostname = oci_load_balancer_hostname.ebscm.name

  cm_cert = "placeholder"
}

output "lb_ip_address" {
  value = oci_load_balancer_load_balancer.ebscm.ip_address_details[0]["ip_address"]
}

# logic


# resource or mixed module blocks

resource "oci_load_balancer_load_balancer" "ebscm" {
  shape = "flexible"
  shape_details {
    maximum_bandwidth_in_mbps = "10"
    minimum_bandwidth_in_mbps = "10"
  }
  compartment_id = local.cm_compartment
  subnet_ids     = [local.cm_lb_subnet_id]
  display_name   = "ebscm_lbaas"
  is_private     = var.private_lb_ip
}


resource "oci_load_balancer_hostname" "ebscm" {
    #Required
    hostname = var.cm_hostname
    load_balancer_id = oci_load_balancer_load_balancer.ebscm.id
    name = "ebs cm"

    #Optional
    lifecycle {
        create_before_destroy = true
    }
}



resource "oci_load_balancer_backendset" "ebscm" {
  name             = "ebscm_lbaas_bes"
  load_balancer_id = local.lb_id
  policy           = "ROUND_ROBIN"

  health_checker {
    interval_ms         = 3000
    timeout_in_millis   = 1000
    port                = "8081"
    protocol            = "HTTP"
    response_body_regex = ".*"
    url_path            = "/cm/ui/index.html"
  }

  session_persistence_configuration {
    cookie_name      = "*"
    disable_fallback = false
  }
}

resource "oci_load_balancer_backend" "ebscm" {
  load_balancer_id = local.lb_id
  backendset_name  = oci_load_balancer_backendset.ebscm.name
  ip_address       = oci_core_instance.ebscm.private_ip   #TODO: can we change this to use the instance ocid
  port             = 8081
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}


resource "null_resource" "generate-lbaas-cert" {
  provisioner "local-exec" {
    command = "openssl req -subj \"/CN=${var.cm_hostname}\" -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout ./dummycert.key -out ./dummycert.crt"
  }
}


resource "oci_load_balancer_certificate" "ebscm" {
  count = ! var.generate_cert ? 1 : 0

  certificate_name   = "ebscm_imported_cert"
  load_balancer_id   = oci_load_balancer_load_balancer.ebscm.id
  
  # ca_certificate     = var.cm_ca_cert != null ? var.cm_ca_cert : replace("=${oci_load_balancer_load_balancer.ebscm.id}=${file("./dummycert.crt")}", "=${oci_load_balancer_load_balancer.ebscm.id}=", "")
  private_key        = var.cm_key_cert != null ? base64decode(var.cm_key_cert) : replace("=${oci_load_balancer_load_balancer.ebscm.id}=${file("./dummycert.key")}", "=${oci_load_balancer_load_balancer.ebscm.id}=", "")
  public_certificate = var.cm_public_cert != null ? base64decode(var.cm_public_cert) : replace("=${oci_load_balancer_load_balancer.ebscm.id}=${file("./dummycert.crt")}", "=${oci_load_balancer_load_balancer.ebscm.id}=", "")
  
  lifecycle {
    create_before_destroy = true
    ignore_changes = [ca_certificate, private_key, public_certificate]
  }

  depends_on = [
    null_resource.generate-lbaas-cert
  ]
}


resource "oci_load_balancer_listener" "ebscm" {
  count = ! var.generate_cert ? 1 : 0
  load_balancer_id         = local.lb_id
  name                     = "ebscm_lbaas_listener"
  default_backend_set_name = oci_load_balancer_backendset.ebscm.name


  port                     = 443
  protocol                 = "HTTP"
  hostname_names = [ local.hostname ]
  
  ssl_configuration {
    certificate_name        = oci_load_balancer_certificate.ebscm[0].certificate_name
    verify_peer_certificate = false
  }

  connection_configuration {
    backend_tcp_proxy_protocol_version = "0"
    idle_timeout_in_seconds            = "60"
  }

  rule_set_names = [
  ]

}



# TODO: backlogged: add support for OCI generated certs
resource "oci_load_balancer_listener" "generated_ebscm" {
  count = var.generate_cert ? 1 : 0
  load_balancer_id         = local.lb_id
  name                     = "ebscm_lbaas_listener"
  default_backend_set_name = oci_load_balancer_backendset.ebscm.name


  port                     = 443
  protocol                 = "HTTP"
  hostname_names = [ local.hostname ]
  


  ssl_configuration {
    certificate_ids = [local.cm_cert]
    verify_peer_certificate = false

    cipher_suite_name = "oci-default-ssl-cipher-suite-v1"
    protocols = [
      "TLSv1.2",
    ]
    server_order_preference = "DISABLED"
    trusted_certificate_authority_ids = [
    ]
    verify_depth            = "1"
    
  }

  connection_configuration {
    backend_tcp_proxy_protocol_version = "0"
    idle_timeout_in_seconds            = "60"
  }

  rule_set_names = [
  ]

}




