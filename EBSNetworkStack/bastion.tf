# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# inputs


variable "create_bastion_subnet" {
  type        = bool
  default     = true
  description = "if true, creates a dedicated subnet for the bastion service or traditional bastion and jump hosts"
}
variable "bastion_subnet_cidr" {
  default = "10.0.0.0/24"
}

variable "use_bastion_service" {
  type = bool 
  default = true 
  description = "If true, creates a bastion service and restricts bastion subnet to not allow any internet traffic. Otherwise bastion subnet will have full internet access for a traditional bastion"

}

variable "bastion_ttl_limit" {
    description = "max length of time a bastion session can remain open in seconds. allowed values are between 30 minutes and 3 hours"
    default = 3 * 60 * 60 
}

variable "bastion_allow_list" {
  type = list(string)
  description = "a list of external IP ranges in CIDR notation that can make inbound ssh connections"
  default = null
}


/* expected defined values
local.network_compartment
local.vcn_prefix
local.bastion_subnet_id

local.vcn_id 
local.vcn_cidrs 
local.service_gateway 
local.service_cidr 
local.nat_gateway 
local.internet_gateway 


*/

# outputs

# logic

locals {
  bastion_internet_access = var.use_bastion_service ? "none" : "full"


  bastion_subnet_id = var.create_bastion_subnet ? module.bastion-SN[0].subnet_id : null 
}


# resource or mixed module blocks


resource "oci_bastion_bastion" "name" {
    count = var.create_bastion_subnet && var.use_bastion_service ? 1 : 0
    bastion_type = "STANDARD"
    compartment_id = local.network_compartment
    target_subnet_id = local.bastion_subnet_id
    client_cidr_block_allow_list = var.bastion_allow_list
    name = "${local.vcn_prefix}-bastion"
    max_session_ttl_in_seconds = var.bastion_ttl_limit 
}

module "bastion-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_bastion_subnet ? 1 : 0

  compartment     = local.network_compartment
  vcn             = local.vcn_id
  vcn_cidrs       = module.vcn[0].cidrs
  prefix          = "${local.vcn_prefix}-bastion"
  subnet_dns_label = "${var.ebs_workload_prefix}bastion"
  ssh_cidr        = local.bastion_internet_access == "full" ? "0.0.0.0/0" : local.ssh_cidr
  cidr_block      = var.bastion_subnet_cidr
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr = module.vcn[0].service_cidr 
  internet_access = local.bastion_internet_access
  network_gateway_id = local.bastion_internet_access == "full" ? module.vcn[0].internet_gateway : null

}