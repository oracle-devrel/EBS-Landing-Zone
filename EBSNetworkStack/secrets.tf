# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.

# inputs

# secret load vars
variable "load_from_secrets" {
    type = bool
    default = true
    description = "if true, will load data via secrets. Uses identity_secret_ocid"
}
variable "secret_compartment" {
  default = null
  description = "used by RM schema and when loading secrets using default naming convention"
} 

variable "identity_secret_ocid" {
    default = null
}


# secret output vars
variable "create_output_secret" {
  type = bool
  default = true
  description = "If true, creates a secret to publish output information. Requires loading data from secrets"
}
variable "secret_type" {
  type = string 
  default = "network"
}


# alternate inputs to secrets
variable "network_compartment" {
  type = string
  default = null
}
variable "security_compartment" {
  type = string
  default = null
}


/* expected defined values
local.environment_prefix
var.ebs_workload_environment_name

local.cm_prefix


local.out_lb_snet_id - ocid
local.out_cm_snet_id - ocid
*/




# outputs


# logic

locals {


  identity_secret_ocid =  var.load_from_secrets && var.identity_secret_ocid == null ? data.oci_vault_secrets.identity[0].secrets[0].id : var.identity_secret_ocid 



  # secret inputs
  security_compartment = var.load_from_secrets ? module.secret-data[0].contents["identity"].security_compartment : var.security_compartment
  network_compartment = var.load_from_secrets ? module.secret-data[0].contents["identity"].network_compartment : var.network_compartment


  # output secret
  /*
  network_secret = tomap ({
      vcn_id = local.vcn_id,
      bastion_subnet_id = local.bastion_subnet_id,
      cm_subnet_id = local.cm_snet_id,
      
      lb_subnet_id = local.lb_subnet_id,
      apps_subnet_id = local.apps_subnet_id,
      db_subnet_id = local.db_subnet_id,

      lb_id = local.lb_id,
      hostname = local.hostname
  })

  */


  secrets = merge (
    var.create_cm_subnets ?
    { "${var.secret_type}-${local.cm_prefix}" = {
      contents = {
        vcn_id = local.vcn_id,
        cm_lb_subnet_id = local.cm_lb_snet_id,
        cm_app_subnet_id = local.cm_snet_id,
      },
      description = "network secret for ebs cm"
      }
    } : null,

    var.create_lb_app_subnets || var.create_ext_lb_app_subnets ?
    { "${var.secret_type}-${local.environment_prefix}" = {
      contents = {
      lb_subnet_id = local.lb_subnet_id,
      apps_subnet_id = local.apps_subnet_id,
      db_subnet_id = local.db_subnet_id,
      ext_lb_subnet_id = local.ext_lb_subnet_id,
      ext_apps_subnet_id = local.ext_apps_subnet_id,
      fs_subnet_id = local.fs_subnet_id,
      },
      description = "network secret for ebs environment: ${var.ebs_workload_environment_name}"
      }
    } : null,

  )

}

# resource or mixed module blocks

# searches for secrets with default naming convention
data "oci_vault_secrets" "identity" {
    count = var.load_from_secrets && var.identity_secret_ocid == null ? 1 : 0
    compartment_id = var.secret_compartment

    name = "identity-${local.environment_prefix}"
}


# loads a secret
module "secret-data" {
    source = "github.com/oracle-devrel/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/secret-data/module"
    count = var.load_from_secrets ? 1 : 0

    secret_ocids = {
      "identity" = local.identity_secret_ocid
    }

}


# creates an output secret
module "secret" {
    source = "github.com/oracle-devrel/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/secret/module"
    count = var.load_from_secrets && var.create_output_secret ? 1 : 0

    compartment = local.security_compartment

    existing_vault = module.secret-data[0].vault

    existing_AES_key = module.secret-data[0].key

    secrets = local.secrets

}