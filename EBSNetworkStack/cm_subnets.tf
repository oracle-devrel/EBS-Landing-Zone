# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# inputs

variable "create_cm_subnets" {
  type        = bool
  default     = true
  description = "if true, creates a dedicated cm lb and app subnet for ebs cm"
}
variable "cm_lb_subnet_cidr" {
  default = "10.0.1.0/24"
}
variable "cm_app_subnet_cidr" {
  default = "10.0.2.0/24"
}

# outputs


# logic

locals {
  cm_prefix = "${local.vcn_prefix}-cm"


  cm_lb_snet_id     = var.create_cm_subnets ? module.CM-LB-SN[0].subnet_id : null
  cm_snet_id        = var.create_cm_subnets ? module.EBSCM-SN[0].subnet_id : null


}


# resource or mixed module blocks

module "CM-LB-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_cm_subnets ? 1 : 0

  compartment     = local.network_compartment
  vcn             = local.vcn_id
  vcn_cidrs       = module.vcn[0].cidrs
  prefix          = "${local.cm_prefix}-lb"
  subnet_dns_label = "${var.ebs_workload_prefix}cmlb"
  internet_access = "nat"
  ssh_cidr        = local.ssh_cidr
  cidr_block      = var.cm_lb_subnet_cidr
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr = module.vcn[0].service_cidr 
  network_gateway_id = module.vcn[0].nat_gateway
  custom_tcp_ingress_rules = { cm_app = {
    source_cidr = local.vcn_cidr, #  IP addresses of your client machines that will access the Cloud Manager UI
    min         = 443,
    max         = 443,
  } }

}


module "EBSCM-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_cm_subnets ? 1 : 0

  compartment     = local.network_compartment
  vcn             = local.vcn_id
  vcn_cidrs       = module.vcn[0].cidrs
  prefix          = "${local.cm_prefix}-app"
  subnet_dns_label = "${var.ebs_workload_prefix}cmapp"
  internet_access = "nat"
  ssh_cidr        = local.ssh_cidr
  cidr_block      = var.cm_app_subnet_cidr
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr = module.vcn[0].service_cidr 
  network_gateway_id = module.vcn[0].nat_gateway
  custom_tcp_ingress_rules = { lb = {
    source_cidr = var.cm_lb_subnet_cidr, # is this rule needed?
    min         = 8081,
    max         = 8081,
    },
    apps = {
      source_cidr = var.apps_subnet_cidr,
      min         = 443,
      max         = 443,
    },
    db = {
      source_cidr = var.db_subnet_cidr,
      min         = 443,
      max         = 443,
    },
  }
}