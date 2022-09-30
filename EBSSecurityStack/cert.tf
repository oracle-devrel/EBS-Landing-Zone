# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# inputs


variable "generate_root_cert" {
  type = bool 
  default = true
  description = "if true, creates a new root CA. if false and you want to generate certs, you will need to provide an imported cert chain"
}

variable "root_cert_common_name" {
  type = string 
  default = "MyCompany"
  description = "name for the root certificate. used as both the common name within cert and user friendly name in OCI"
}

# TODO: not supporting external certs yet
variable "imported_cert_chain" {
  type = string 
  default = null
  description = "root or intermediate certificate to import into OCI cert service."
}


# TODO: not implementing intermediate CAs yet
variable "generate_intermediate_cert" {
  type = bool 
  default = true 
  description = "if true, creates a new intermediate CA between your root/current cert chain and the leaf certificate"
}

variable "generate_ebscm_cert" {
  type        = bool
  default     = true
  description = "If false, you must provide your own leaf certificate"
}

variable "ebscm_dns_name" { # TODO: can we get this info from network stack
  type    = string
  default = "cm.ebs.com"
}

variable "imported_ebscm_cert_bundle" {
  type = string 
  default = null 
  description = "if you are using an external cert service to create your ebscm leaf cert, you still need to import the cert bundle to OCI"
}








# outputs


# logic

locals {

 cm_cert = oci_certificates_management_certificate.ebscm[0].id

 
}



# resource or mixed module blocks


# TODO: need to add Dynamic group/policy to enable cert service https://docs.oracle.com/en-us/iaas/Content/certificates/managing-certificate-authorities.htm#CA_required_iam_policy
resource "oci_certificates_management_certificate_authority" "root" {
  count = var.generate_ebscm_cert && var.generate_root_cert ? 1 : 0
  certificate_authority_config {
    config_type = "ROOT_CA_GENERATED_INTERNALLY"
    subject {
      common_name = var.root_cert_common_name
      # TODO: what additional subject information will customers want to sign with
    }
  }

  compartment_id = local.security_compartment
  kms_key_id     = oci_kms_key.CAMasterKey.id
  name           = var.root_cert_common_name # needs to be unique within compartment. maybe needs random id
}

/* TODO: we're going to KISS and ignore intermediate CAs for now
resource "oci_certificates_management_certificate_authority" "intermediate" {
  count = var.generate_ebscm_cert ? 1 : 0
  certificate_authority_config {
    config_type = "ROOT_CA_GENERATED_INTERNALLY"
    subject {
      common_name = var.ebscm_dns_name
    }
  }

  compartment_id = local.security_compartment
  kms_key_id     = oci_kms_key.CAMasterKey.id
  name           = "CM_CA_Cert_3"
}
*/


resource "oci_certificates_management_certificate" "ebscm" {
  count = var.generate_ebscm_cert ? 1 : 0
  #Required
  certificate_config {
    #Required
    config_type = "ISSUED_BY_INTERNAL_CA"

    certificate_profile_type        = "TLS_SERVER_OR_CLIENT"
    issuer_certificate_authority_id = oci_certificates_management_certificate_authority.root[0].id

    subject {
      common_name = var.ebscm_dns_name
    }

  }
  compartment_id = local.security_compartment
  name           = "CM_Leaf_Cert_1"

}
