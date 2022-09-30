# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.

# inputs

variable "lz_prefix" {
  default = "lz"
  description = "must match variable name in identity stack"
}

variable "ebs_workload_prefix" {
  default = "ebs"
  description = "must match variable name in identity stack"
}

variable "ebs_workload_environment_name" {
  type = string
  default = null
  description = "a single environment that will use this network. Must be from the variable name list in identity stack. a cm environment name will also be automatically used if turned on"
}

variable "advanced_options" {
  # only used in RM schema
}



variable "create_vcn" {
  type = bool 
  default = true
}
variable "existing_vcn" {
  type        = string
  default     = null
  description = "required if create_vcn is false. Will load vcn and gateways from the given vcn OCID"
}
variable "vcn_cidr" {
  default = "10.0.0.0/16"
}

# outputs


# logic

locals {

    vcn_prefix = "${var.lz_prefix}-${var.ebs_workload_prefix}"
    environment_prefix = "${local.vcn_prefix}-${var.ebs_workload_environment_name}"

    vcn_id = var.create_vcn ? module.vcn[0].vcn : module.vcn-data[0].vcn
    vcn_cidrs = var.create_vcn ? module.vcn[0].cidrs : module.vcn-data[0].cidrs 
    service_gateway = var.create_vcn ? module.vcn[0].service_gateway : module.vcn-data[0].service_gateway
    service_cidr = var.create_vcn ? module.vcn[0].service_cidr : module.vcn-data[0].service_cidr
    nat_gateway = var.create_vcn ? module.vcn[0].nat_gateway : module.vcn-data[0].nat_gateway
    internet_gateway = var.create_vcn ? module.vcn[0].internet_gateway : module.vcn-data[0].internet_gateway

    vcn_cidr = var.create_vcn ? module.vcn[0].cidrs[0] : module.vcn-data[0].cidrs[0]

    anywhere = "0.0.0.0/0"

}


# resource or mixed module blocks


module "vcn" {
  count  = var.create_vcn ? 1 : 0
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-vcn/module?ref=EBSsubmodules"

  compartment_id   = local.network_compartment
  vcn_display_name = local.vcn_prefix
  cidr_blocks      = [var.vcn_cidr]

  create_service_gateway  = true
  create_nat_gateway      = true
  create_internet_gateway = true
  vcn_dns_label = "${var.lz_prefix}${var.ebs_workload_prefix}"
}

module "vcn-data" {
    count = ! var.create_vcn ? 1 : 0
    source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-vcn-data/module?ref=EBSsubmodules"

    vcn_id = var.existing_vcn 
}