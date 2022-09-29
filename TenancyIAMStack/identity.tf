# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.

# inputs

variable "lz_prefix" {
    description = "used to create unique names across identity resources in the tenancy and differentiate different LZ implementations"
    default = "lz"
}

variable "parent_compartment_ocid" {
    description = "the ocid of an existing compartment to branch off of and make new subcompartments under"
}

variable "advanced_options" {
  # only used in RM schema
}

variable "create_identity_personas" {
    default = true
    description = "creates one group for managing user credentials and another to manage any other IAM resource across the tenancy"
}


variable "create_network_compartment" {
    default = true
}
variable "network_name" {
    default = "network"
    description = "name to give network compartment, groups, and policy. prefix will be automatically appended"
}
variable "network_compartment_ocid" {
    default = null
    description = "not required if you are not using secrets. However, your network will need to live somewhere"
}

variable "create_security_compartment" {        
    default = true 
}
variable "security_name" {
    default = "security"
    description = "name to give security compartment, groups, and policy. prefix will be automatically appended"
}
variable "security_compartment_ocid" {
    default = null 
    description = "not required if you are not using secrets, OCI certificates, or OCI bastion service"
}
variable "enable_certificates" {
    type = bool
    default = false
    description = "if true, creates a dynamic group and policy that is required to use the certificate service"
}


variable "create_ebs_workload_compartment" {
    default = true
}
variable "ebs_workload_prefix" {
    default = "ebs"
    description = "used to identify resources to use/are created for a specific workload in the landing zone"
}
variable "ebs_workload_compartment_ocid" {
    default = null
}
variable "ebs_workload_environment_names" {
    type = list(string)
    default = []
    description = "for each entry in the list, creates a sub-compartment within the top ebs compartment in order to isolate environments at the IAM level. only used if creating an ebs workload compartment"
}


variable "create_ebs_group" {
    default = false
    description = "if you are using an existing compartment for ebs, you can create just an ebs group and policy within that existing compartment by setting this to true"
}
variable "new_ebs_group_name" {
    default = "ebs"
}



# outputs

locals {
    network_compartment = var.create_network_compartment ? module.identity.network_compartment : var.network_compartment_ocid
    security_compartment = var.create_security_compartment ? module.identity.security_compartment : var.security_compartment_ocid
    application_compartment = var.create_ebs_workload_compartment ? module.identity.application_compartment : var.ebs_workload_compartment_ocid
    database_compartment = local.application_compartment
}


# logic


# resource or mixed module blocks


module "identity" {
    # TODO: switch back to devrel project once code is merge
    source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/identity/module"

    tenancy_ocid = var.tenancy_ocid
    existing_compartment = var.parent_compartment_ocid
    prefix = var.lz_prefix

    create_identity_persona = var.create_identity_personas

    create_network_persona = var.create_network_compartment
    network_name = var.network_name # var.network_group_name

    create_security_persona = var.create_security_compartment 
    security_name = var.security_name
    enable_ca = var.create_security_compartment && var.enable_certificates  #certificates currently require the security compartment to be created

    create_application_persona = var.create_ebs_workload_compartment
    application_name = var.ebs_workload_prefix
    application_type = "ebs"
    application_environments = var.ebs_workload_environment_names != [] ? concat(var.ebs_workload_environment_names, ["cm"]) : [] #if we are creating isolated environments, add an additional isolated compartment for the cm


}

module "ebs_standalone" {
    source = "github.com/oracle-devrel/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/identity/module"

    tenancy_ocid = var.tenancy_ocid
    existing_compartment = var.ebs_workload_compartment_ocid
    prefix = var.lz_prefix

    create_custom_persona = var.create_ebs_group
    create_custom_compartment = false 
    custom_persona_name = var.new_ebs_group_name
    custom_policy_permissions = [
        "manage database-family", "manage autonomous-database-family", "manage load-balancers", "manage tag-namespaces", 
        "manage instance-family","manage functions-family", "manage cluster-family", "manage volume-family", 
        "manage object-family", "manage repos", "manage api-gateway-family", "manage bastion-session", 
        "manage streams", "manage ons-family", "manage alarms", "manage metrics", "manage logs", "manage cloudevents-rules", 
        "manage orm-stacks", "manage orm-jobs", "manage orm-config-source-providers", "manage file-systems", "manage export-sets", 
        "read all-resources", "read audit-events", "read work-requests", "read instance-agent-plugins"
    ]

}