# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# inputs


variable "create_output_secrets" {
  type = bool
  default = true
  description = "If true, creates a secret to publish output information to a secret in the oci vault. Other Landing Zone stacks can then consume that secret for input information"
}


#vault vars
variable "create_vault" {
  type = bool 
  default = true
}
variable "existing_vault" {
    type = string 
    default = null
    description = "ocid of an existing vault"
}
variable "vault_name" {
  type        = string
  description = "Vault Name"
  default     = "vault"
}
variable "vault_type" {
  type        = string
  description = "Vault Type - DEFAULT (Shared)"
  default     = "DEFAULT"
}


# key
variable "create_secret_key" {
  type = bool 
  default = true
}
variable "existing_secret_key" {
  type = string 
  default = null
}
variable "secret_key_name" {
  type = string
  default = "secretkey"
}


# secret
variable "secret_type" { 
  type = string 
  default = "identity"
}

/* expected defined values
var.lz_prefix
var.ebs_workload_prefix
local.security_compartment
local.security_compartment - ocid
local.network_compartment - ocid
local.application_compartment - ocid
local.dba_compartment - ocid
*/

# outputs


# logic 

locals {

  vault_name = "${var.lz_prefix}-${var.vault_name}"
  secret_key_name = "${var.lz_prefix}-${var.secret_key_name}"


  secret_contents = {
      network_compartment = local.network_compartment,
      security_compartment = local.security_compartment,
      application_compartment = local.application_compartment,
      database_compartment = local.database_compartment,
  }

  secrets = merge (
    { "${var.secret_type}-${var.lz_prefix}-${var.ebs_workload_prefix}" = {
      contents = local.secret_contents,
      description = "identity secret for general ebs workload"
      }
    },
    {for name, ocid in module.identity.appplication_environment_compartments :
      "${var.secret_type}-${name}" => 
      {
        contents = {
          network_compartment = local.network_compartment,
          security_compartment = local.security_compartment,
          application_compartment = ocid,
          database_compartment = ocid,
        },
        description = "identity secret for ebs environment: ${name}"
      }
      }
  )


}


# resource or mixed module blocks



module "secret" {
    source = "github.com/oracle-devrel/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/secret/module"
    count = var.create_output_secrets ? 1 : 0

    compartment = local.security_compartment

    existing_vault = !var.create_vault ? var.existing_vault : null
    vault_name = local.vault_name 
    vault_type = var.vault_type 

    existing_AES_key = !var.create_secret_key ? var.existing_secret_key : null 
    AES_key_name = local.secret_key_name 

    secrets = local.secrets 

}