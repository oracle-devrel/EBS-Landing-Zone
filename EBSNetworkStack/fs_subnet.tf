# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# inputs

variable "create_fs_subnet" {
  type = bool 
  default = false
  description = "if true, creates a dedicated File Storage subnet for ebs environment(s)"
}

variable "existing_fs_subnet_ocid" {
    type = string 
    default = null
    description = "ocid of an existing fs subnet. only used if create_fs_subnet is false. if not null, any internal or external app subnets will include network rules for the fs subnet. additional_app_subnet_cidrs will also need to be used in the stack the fs subnet is created in"
}

variable "fs_subnet_cidr" {
  default = "10.0.8.0/24"
  description = "cidr used when creating a new fs subnet"
}

variable "mount_target_ad" {
    default = null
}

variable "additional_app_subnet_cidrs" {
    type = list(string)
    default = []
    description = "the cidr blocks of any internal or external app subnets created by different network stacks. By default, the routing between any internal or external app subnets and a file storage subnet created in the same stack will be included. existing_fs_subnet_ocid will also need to be used in the different network stacks"
}

# outputs



# logic


locals{


    fs_subnet_id = var.create_fs_subnet ? module.FS-SN[0].subnet_id : null


    fs_subnet_cidr = (
        var.create_fs_subnet 
            ? module.FS-SN[0].subnet_cidr 
            : var.existing_fs_subnet_ocid != null 
                ? data.oci_core_subnet.fs[0].cidr_block
                : null

    )

/*
    # applied to both ingress and egresss for each app subnet
    fs_tcp_rules = {
        "111" = {
            min = 111
            max = 111
        },
        "2000range" = {
            min = 2048
            max = 2050
        },

    }
    fs_udp_rules = {
        "111" = {
            min = 111,
            max = 111
        },
        "2048" = {
            min = 2048,
            max = 2048
        }
    }
    */


    # list of all application subnet cidrs including created and external subnets
    fs_app_subnet_cidrs = concat (
        var.create_lb_app_subnets ? [var.apps_subnet_cidr] : [],
        var.create_ext_lb_app_subnets ? [var.ext_apps_subnet_cidr] : [],
        var.additional_app_subnet_cidrs
    )


    # tcp ingress
    fs_tcp_ingress = merge (
    {
        for cidr in local.fs_app_subnet_cidrs :
            "${cidr}-111" => {
                source_cidr = cidr,
                min = 111,
                max = 111,
            }
    },
    {
        for cidr in local.fs_app_subnet_cidrs :
            "${cidr}-2000range" => {
                source_cidr = cidr,
                min = 2048,
                max = 2050,
            }
    }
    )

    # tcp egress
    fs_tcp_egress = merge (
    {
        for cidr in local.fs_app_subnet_cidrs :
            "${cidr}-111" => {
                dest_cidr = cidr,
                min = 111,
                max = 111,
            }
    },
    {
        for cidr in local.fs_app_subnet_cidrs :
            "${cidr}-2000range" => {
                dest_cidr = cidr,
                min = 2048,
                max = 2050,
            }
    }
    )

    # udp ingress
    fs_udp_ingress = merge (
    {
        for cidr in local.fs_app_subnet_cidrs :
            "${cidr}-111" => {
                source_cidr = cidr,
                min = 111,
                max = 111,
            }
    },
    {
        for cidr in local.fs_app_subnet_cidrs :
            "${cidr}-2048" => {
                source_cidr = cidr,
                min = 2048,
                max = 2048,
            }
    }
    )


    # udp egress
    fs_udp_egress = merge (
    {
        for cidr in local.fs_app_subnet_cidrs :
            "${cidr}-111" => {
                dest_cidr = cidr,
                min = 111,
                max = 111,
            }
    },
    {
        for cidr in local.fs_app_subnet_cidrs :
            "${cidr}-2048" => {
                dest_cidr = cidr,
                min = 2048,
                max = 2048,
            }
    }
    )

}



# resource or mixed module blocks


module "FS-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_fs_subnet ? 1 : 0

  # vcn info
  vcn             = local.vcn_id
  vcn_cidrs       = module.vcn[0].cidrs
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr = module.vcn[0].service_cidr 
  network_gateway_id = module.vcn[0].nat_gateway

  # subnet specs
  compartment     = local.network_compartment
  prefix          = "${local.environment_prefix}-fs"
  subnet_dns_label = "${var.ebs_workload_prefix}${var.ebs_workload_environment_name}fs"
  internet_access = "nat"
  cidr_block      = var.fs_subnet_cidr


  # tcp ingress rules
  custom_tcp_ingress_rules = local.fs_tcp_ingress


  # tcp egress rules
    custom_tcp_egress_rules = local.fs_tcp_egress


    # udp
    custom_udp_ingress_rules = local.fs_udp_ingress
    custom_udp_egress_rules = local.fs_udp_egress


  all_outbound_traffic = false

  
}



resource "oci_file_storage_mount_target" "this" {
    count = var.create_fs_subnet ? 1 : 0

    #Required
    availability_domain = var.mount_target_ad
    compartment_id = local.network_compartment
    subnet_id = local.fs_subnet_id
    display_name = "${local.environment_prefix}-fsmount"


    /*
    hostname_label = var.mount_target_hostname_label
    ip_address = var.mount_target_ip_address
    nsg_ids = var.mount_target_nsg_ids
    */
}



data "oci_core_subnet" "fs" {
    count = !var.create_fs_subnet && var.existing_fs_subnet_ocid != null ? 1 : 0
    subnet_id = var.existing_fs_subnet_ocid
  
}