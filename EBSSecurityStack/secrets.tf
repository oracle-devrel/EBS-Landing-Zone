# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# inputs

# secret load vars
variable "load_from_secrets" {
    type = bool
    default = true
    description = "if true, will load data via secrets. Uses identity_secret_ocid"
}
variable "secret_compartment" {} # used by RM schema

variable "identity_secret_ocid" {
    default = null
}

variable "network_secret_ocid" {
    default = null
}

# secret output vars
variable "create_output_secret" {
  type = bool
  default = true
  description = "If true, creates a secret to publish output information. Requires loading data from secrets"
}
variable "output_secret_name" {
  type = string 
  default = "security"
}


variable "bastion_subnet_id" {
  type = string 
  description = "subnet ocid to create the bastion in"
  default = ""
}


/* expected defined values
local.out_lb_snet_id - ocid
local.out_cm_snet_id - ocid
*/




# outputs


# logic

locals {

  # secret inputs
  security_compartment = module.secret-data[0].contents["identity"].security_compartment
  #network_compartment = module.secret-data[0].content.network_compartment
  
  bastion_subnet_id = var.load_from_secrets ? module.secret-data[0].contents["network"].bastion_subnet_id : var.bastion_subnet_id
 
  vault = module.secret-data[0].vault

  # output secret
  security_secret = tomap ({
      cm_cert = local.cm_cert
  })

}

# resource or mixed module blocks

# loads a secret
module "secret-data" {
    source = "github.com/oracle-devrel/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/secret-data/module"
    count = var.load_from_secrets ? 1 : 0

    secret_ocids = {
      "identity" = var.identity_secret_ocid,
      "network" = var.network_secret_ocid,
    }

}


# creates an output secret
module "secret" {
    source = "github.com/oracle-devrel/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/secret/module"
    count = var.create_output_secret ? 1 : 0

    compartment = local.security_compartment

    existing_vault = local.vault

    existing_AES_key = module.secret-data[0].key

    secrets = {
      "${var.output_secret_name}" = {
        contents = local.security_secret 
        description = "security secret for ebs cm"
      }
    }

}