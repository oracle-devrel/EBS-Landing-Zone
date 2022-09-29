# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.

# inputs

#naming convention
variable "lz_prefix" {
    description = "used to create unique names across identity resources in the tenancy and differentiate different LZ implementations"
    default = "lz"
}
variable "ebs_workload_prefix" {
    default = "ebs"
    description = "used to identify resources to use/are created for a specific workload in the landing zone"
}
variable "ebs_workload_environment_name" {
  type = string
  default = null
  description = "The environment name used for an ebs environment to load the network zone into ebs. The cm environment is used automatically. This must be the same as what is used in the identity and network stacks. currently only a single environment is supported"
}
variable "advanced_options" {
  # only used in RM schema
}



# secret load vars
variable "load_from_secrets" {
    type = bool
    default = true
    description = "if true, will load data via secrets."
}
variable "secret_compartment" {
    default = null 
    description = "used by RM schema and when loading secrets using default naming convention"
} # used by RM schema

variable "identity_secret_ocid" {
    default = null
}
variable "network_secret_ocid" {
    default = null
    description = "secret for the EBS CM network"
}
variable "environment_network_secret_ocid" {
    default = null 
    description = "secret for an EBS environment network"
}

/*
variable "security_secret_ocid" {
    default = null
}
*/

# secret output vars
variable "create_output_secret" {
  type = bool
  default = true
  description = "If true, creates a secret to publish output information. Requires loading data from secrets"
}
variable "secret_type" {
  type = string 
  default = "app"
}


# alternate inputs to secrets
variable "cm_compartment" {
    type = string 
    default = null
}

variable "network_compartment" {
    type = string
    default = null
}

variable "security_compartment" {
    type = string 
    default = null
}

variable "ebs_cm_admin_group" {
  type        = string
  default = null
  description = "The group ocid for ebs cm administrators. Used to grant additional pivelidges within the CM Console."
}

variable "cm_hostname" {
  type        = string
  description = "If the server host is myebscm.example.com, EBS Cloud Manager login URL will be https://myebscm.example.com:8081"
  default     = "myebscm.example.com"
}



variable "vcn_id" {
    default = ""
}
variable cm_lb_subnet_id {
    default = ""
}
variable cm_app_subnet_id {
  default = ""

}


variable "lb_subnet_id" {
  default = ""
}
variable "apps_subnet_id" {
    default = ""
}
variable "db_subnet_id" {
    default = ""
}
variable "ext_lb_subnet_id" {
    default = ""
}
variable "ext_apps_subnet_id" {
    default = ""
}





/* expected defined values

*/




# outputs


# logic

locals {


workload_prefix = "${var.lz_prefix}-${var.ebs_workload_prefix}"

identity_secret_ocid =  var.load_from_secrets && var.identity_secret_ocid == null ? data.oci_vault_secrets.identity[0].secrets[0].id : var.identity_secret_ocid 
network_secret_ocid =  var.load_from_secrets && var.network_secret_ocid == null ? data.oci_vault_secrets.network[0].secrets[0].id : var.network_secret_ocid 
network_environment_secret_ocid = var.load_from_secrets && var.environment_network_secret_ocid == null ? data.oci_vault_secrets.network-environment[0].secrets[0].id : var.environment_network_secret_ocid

  # secret inputs
  security_compartment = var.load_from_secrets ? module.secret-data[0].contents["identity"].security_compartment : var.security_compartment
  network_compartment = var.load_from_secrets ? module.secret-data[0].contents["identity"].network_compartment : var.network_compartment
  cm_compartment = var.load_from_secrets ? module.secret-data[0].contents["identity"].application_compartment : var.cm_compartment
  cm_admin_group = var.load_from_secrets ? data.oci_identity_groups.cm_admins[0].groups[0].id : var.ebs_cm_admin_group

  
    vcn_id = var.load_from_secrets ? module.secret-data[0].contents["network"].vcn_id : var.vcn_id 
    cm_lb_subnet_id = var.load_from_secrets ? module.secret-data[0].contents["network"].cm_lb_subnet_id : var.cm_lb_subnet_id
    cm_app_subnet_id = var.load_from_secrets ? module.secret-data[0].contents["network"].cm_app_subnet_id : var.cm_app_subnet_id
    
    lb_subnet_id = var.load_from_secrets ? module.secret-data[0].contents["network-environment"].lb_subnet_id : var.lb_subnet_id
    apps_subnet_id = var.load_from_secrets ? module.secret-data[0].contents["network-environment"].apps_subnet_id : var.apps_subnet_id
    db_subnet_id = var.load_from_secrets ? module.secret-data[0].contents["network-environment"].db_subnet_id : var.db_subnet_id
    ext_lb_subnet_id = var.load_from_secrets ? module.secret-data[0].contents["network-environment"].ext_lb_subnet_id : var.ext_lb_subnet_id
    ext_apps_subnet_id = var.load_from_secrets ? module.secret-data[0].contents["network-environment"].ext_apps_subnet_id : var.ext_apps_subnet_id


    vault = module.secret-data[0].vault

  # output secret
  cm_secret = tomap ({
      one = "two"
  })

}

data "oci_identity_groups" cm_admins { # TODO: this should probably just be passed with the identity secret
    count = var.load_from_secrets ? 1 : 0
    compartment_id = var.tenancy_ocid
    name = "${local.workload_prefix}-cm"
}



# resource or mixed module blocks

# searches for secrets with default naming convention
data "oci_vault_secrets" "identity" {
    count = var.load_from_secrets && var.identity_secret_ocid == null ? 1 : 0
    compartment_id = var.secret_compartment

    name = "identity-${local.workload_prefix}-cm"
}
data "oci_vault_secrets" "network" {
    count = var.load_from_secrets && var.network_secret_ocid == null ? 1 : 0
    compartment_id = var.secret_compartment

    name = "network-${local.workload_prefix}-cm"
}
data "oci_vault_secrets" "network-environment" {
    count = var.load_from_secrets && var.environment_network_secret_ocid == null ? 1 : 0
            
    compartment_id = var.secret_compartment

    name = "network-${local.workload_prefix}-${var.ebs_workload_environment_name}"
}



# loads a secret
module "secret-data" {
    source = "github.com/oracle-devrel/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/secret-data/module"
    count = var.load_from_secrets ? 1 : 0

    secret_ocids = {
        "identity" = local.identity_secret_ocid,
        "network" = local.network_secret_ocid,
        "network-environment" = local.network_environment_secret_ocid,

    }

}


# creates an output secret
module "secret" {
    source = "github.com/oracle-devrel/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/secret/module"
    count = var.load_from_secrets && var.create_output_secret ? 1 : 0

    compartment = local.security_compartment

    existing_vault = local.vault

    existing_AES_key = module.secret-data[0].key

    secrets = {
        "${var.secret_type}-${local.workload_prefix}-cm" = {
            contents = local.cm_secret,
            description = "application secret for ebs cm"
        }
    }

}