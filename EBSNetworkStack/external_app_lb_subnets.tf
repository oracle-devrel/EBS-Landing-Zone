# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.



# inputs

variable "create_ext_lb_app_subnets" {
  type        = bool
  default     = false
  description = "if true, creates a dedicated external (public) load balancer subnet and (private) app subnet for ebs environment(s)"
}
variable "ext_lb_subnet_cidr" {
  default = "10.0.6.0/24"
}
variable "ext_apps_subnet_cidr" {
  default = "10.0.7.0/24"
}


# outputs


# logic

locals {

    ext_lb_subnet_id   = var.create_ext_lb_app_subnets ? module.EXT-LB-SN[0].subnet_id : null
  ext_apps_subnet_id = var.create_ext_lb_app_subnets ? module.EXT-APP-SN[0].subnet_id : null
  

  apps-ext-int-rules = {
    "111" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 111,
      max         = 111,
    },
    "2049" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 2049,
      max         = 2049,
    },
    "5000range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 5556,
      max         = 5557,
    },
    "7200range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 7201,
      max         = 7202,
    },
    "17200range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 17201,
      max         = 17202,
    },
    "7400range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 7401,
      max         = 7402,
    },
    "17400range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 17401,
      max         = 17402,
    },
    "7600range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 7601,
      max         = 7602,
    },
    "17600range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 17601,
      max         = 17602,
    },
    "7800range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 7801,
      max         = 7802,
    },
    "17800range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 17801,
      max         = 17802,
    },
    "6800range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 6801,
      max         = 6802,
    },
    "16800range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 16801,
      max         = 16802,
    },
    "10000range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 9999,
      max         = 10000,
    },
    "1626" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 1626,
      max         = 1626,
    },
    "12345" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 12345,
      max         = 12345,
    },
    "36500range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 36501,
      max         = 36550,
    },
    "6100range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 6100,
      max         = 6101,
    }
    "6200range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 6200,
      max         = 6201,
    },
    "6500range" = {
      source_cidr = var.apps_subnet_cidr,
      min         = 6500,
      max         = 6501,
    }

  }
}


# resource or mixed module blocks



module "EXT-LB-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_ext_lb_app_subnets ? 1 : 0

  # vcn info

  vcn                = local.vcn_id
  vcn_cidrs          = module.vcn[0].cidrs
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr       = module.vcn[0].service_cidr
  network_gateway_id = module.vcn[0].internet_gateway

  # subnet specs
  compartment      = local.network_compartment
  prefix           = "${local.environment_prefix}-extlb"
  subnet_dns_label = "${var.ebs_workload_prefix}${var.ebs_workload_environment_name}extlb"
  internet_access  = "full"
  cidr_block       = var.ext_lb_subnet_cidr


  # tcp ingress rules
  ssh_cidr = local.ssh_cidr
  custom_tcp_ingress_rules = {
    users = {
      source_cidr = local.anywhere,
      min         = 443, #web entry port - do we need to offer option for port 80?
      max         = 443,
  } }

  # tcp egress rules
  all_outbound_traffic       = false
  tcp_all_ports_egress_cidrs = [local.anywhere]

  # icmp rules
  icmp_egress_cidrs = [local.anywhere]
}


module "EXT-APP-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_ext_lb_app_subnets ? 1 : 0

  # vcn info
  vcn                = local.vcn_id
  vcn_cidrs          = module.vcn[0].cidrs
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr       = module.vcn[0].service_cidr
  network_gateway_id = module.vcn[0].nat_gateway

  # subnet specs
  compartment      = local.network_compartment
  prefix           = "${local.environment_prefix}-extapp"
  subnet_dns_label = "${var.ebs_workload_prefix}${var.ebs_workload_environment_name}extapp"
  internet_access  = "nat"
  cidr_block       = var.ext_apps_subnet_cidr


  # tcp ingress rules
  ssh_cidr = local.ssh_cidr
  custom_tcp_ingress_rules = merge(
    {
      "lb" = {
        source_cidr = var.ext_lb_subnet_cidr,
        min         = 8000,
        max         = 8000,
      },
    },
    var.create_lb_app_subnets ? local.apps-ext-int-rules : {},
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

  tcp_all_ports_ingress_cidrs = ["${var.ext_apps_subnet_cidr}"]


  # tcp egress rules
  all_outbound_traffic = false
  custom_tcp_egress_rules = merge(
    {
      "db" = {
        dest_cidr = var.db_subnet_cidr,
        min       = 1521,
        max       = 1524,
      },
      "cm_app" = {
        dest_cidr = var.cm_app_subnet_cidr,
        min       = 443,
        max       = 443,
      }
    },
  )
  tcp_all_ports_egress_cidrs = ["134.70.0.0/17", "${var.ext_apps_subnet_cidr}", "${var.apps_subnet_cidr}"]

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

  # icmp rules
  icmp_ingress_cidrs  = [var.cm_app_subnet_cidr, var.ext_lb_subnet_cidr, var.db_subnet_cidr, var.apps_subnet_cidr, var.ext_apps_subnet_cidr]
  icmp_egress_cidrs   = [local.anywhere]
  icmp_egress_service = true

}