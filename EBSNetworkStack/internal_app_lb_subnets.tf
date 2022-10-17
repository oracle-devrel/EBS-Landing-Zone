# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# inputs




variable "create_lb_app_subnets" {
  type        = bool
  default     = true
  description = "if true, creates a dedicated internal (private) load balancer subnet and (private) app subnet for ebs environment(s)"
}
variable "lb_subnet_cidr" {
  default = "10.0.3.0/24"
}
variable "apps_subnet_cidr" {
  default = "10.0.4.0/24"
}






/* expected defined values
local.network_compartment - ocid
local.anywhere
*/

# outputs

# logic

locals {

  ssh_cidr = var.create_bastion_subnet ? var.bastion_subnet_cidr : local.vcn_cidrs[0]


  lb_subnet_id       = var.create_lb_app_subnets ? module.LB-SN[0].subnet_id : null
  apps_subnet_id     = var.create_lb_app_subnets ? module.APP-SN[0].subnet_id : null



  apps-int-ext-rules = {
    "111" = {
      source_cidr = var.ext_apps_subnet_cidr,
      min         = 111,
      max         = 111,
    },
    "2049" = {
      source_cidr = var.ext_apps_subnet_cidr,
      min         = 2049,
      max         = 2049,
    },
    "7000range" = {
      source_cidr = var.ext_apps_subnet_cidr,
      min         = 7001,
      max         = 7003,
    },
    "6000range" = {
      source_cidr = var.ext_apps_subnet_cidr,
      min         = 6801,
      max         = 6802,
    },
    "16000range" = {
      source_cidr = var.ext_apps_subnet_cidr,
      min         = 16801,
      max         = 16802,
    },
    "12345" = {
      source_cidr = var.ext_apps_subnet_cidr,
      min         = 12345,
      max         = 12345,
    },
    "36000range" = {
      source_cidr = var.ext_apps_subnet_cidr,
      min         = 36501,
      max         = 36550,
    },

  }

  

}


# resource or mixed module blocks




module "LB-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_lb_app_subnets ? 1 : 0

  # vcn info
  vcn                = local.vcn_id
  vcn_cidrs          = module.vcn[0].cidrs
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr       = module.vcn[0].service_cidr
  network_gateway_id = module.vcn[0].nat_gateway

  # subnet specs
  compartment      = local.network_compartment
  prefix           = "${local.environment_prefix}-lb"
  subnet_dns_label = "${var.ebs_workload_prefix}${var.ebs_workload_environment_name}lb"
  internet_access  = "nat" #var.lb_internet_access
  cidr_block       = var.lb_subnet_cidr


  # tcp ingress rules
  ssh_cidr = local.ssh_cidr
  custom_tcp_ingress_rules = {
    lb = {
      source_cidr = local.anywhere,

      min = 443, #web entry port - do we need to offer option for port 80?
      max = 443,
  } }

  # tcp egress rules
  all_outbound_traffic       = false
  tcp_all_ports_egress_cidrs = ["${var.apps_subnet_cidr}"]

  # icmp rules
  icmp_egress_cidrs = [local.anywhere]
}

module "APP-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_lb_app_subnets ? 1 : 0

  # vcn info
  vcn                = local.vcn_id
  vcn_cidrs          = module.vcn[0].cidrs
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr       = module.vcn[0].service_cidr
  network_gateway_id = module.vcn[0].nat_gateway

  # subnet specs
  compartment      = local.network_compartment
  prefix           = "${local.environment_prefix}-app"
  subnet_dns_label = "${var.ebs_workload_prefix}${var.ebs_workload_environment_name}app"
  internet_access  = "nat"
  cidr_block       = var.apps_subnet_cidr

  # tcp ingress rules
  ssh_cidr = local.ssh_cidr
  custom_tcp_ingress_rules = merge(
    {
      "lb" = {
        source_cidr = var.lb_subnet_cidr,
        min         = 8000,
        max         = 8000,
      },


    },
    var.create_ext_lb_app_subnets ? local.apps-int-ext-rules : {},
    local.fs_subnet_cidr != null ?
    {
      "111" = {
        source_cidr = local.fs_subnet_cidr,
        min         = 111,
        max         = 111,
      },
      "2000range" = {
        source_cidr = local.fs_subnet_cidr,
        min         = 2048,
        max         = 2050,
      }
    } : {},
  )

  tcp_all_ports_ingress_cidrs = ["${var.apps_subnet_cidr}"]

  # tcp egress rules
  all_outbound_traffic = false
  custom_tcp_egress_rules = merge(
    var.create_cm_subnets ?
    {
      "cm_app" = {
        dest_cidr = var.cm_app_subnet_cidr,
        min       = 443,
        max       = 443,
      }
    } : {},
    var.create_db_subnet ?
    {
      "db" = {
        dest_cidr = var.db_subnet_cidr,
        min       = 1521,
        max       = 1524,
      }
    } : {},
  )
  tcp_all_ports_egress_cidrs = concat(
    ["134.70.0.0/17", "${var.apps_subnet_cidr}"],
    var.create_ext_lb_app_subnets ? ["${var.ext_apps_subnet_cidr}"] : []
  )


  # udp 
  custom_udp_ingress_rules = merge(
    local.fs_subnet_cidr != null ?
    {
      "111" = {
        source_cidr = local.fs_subnet_cidr,
        min         = 111,
        max         = 111,
      },
      "2048" = {
        source_cidr = local.fs_subnet_cidr,
        min         = 2048,
        max         = 2048,
      }
    } : {},
  )

  custom_udp_egress_rules = merge (
    local.fs_subnet_cidr != null ?
    {
      "111" = {
        dest_cidr = local.fs_subnet_cidr,
        min         = 111,
        max         = 111,
      },
      "2048" = {
        dest_cidr = local.fs_subnet_cidr,
        min         = 2048,
        max         = 2048,
      }
    } : {},
  )


  #icmp rules
  icmp_ingress_cidrs  = [var.cm_app_subnet_cidr, var.lb_subnet_cidr, var.db_subnet_cidr, var.apps_subnet_cidr]
  icmp_egress_cidrs   = [local.anywhere]
  icmp_egress_service = true
}





