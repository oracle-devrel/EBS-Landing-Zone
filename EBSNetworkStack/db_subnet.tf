

# inputs

variable "create_db_subnet" {
  type        = bool
  default     = true
  description = "if true, creates a dedicated database subnet for ebs environment(s)"
}
variable "db_subnet_cidr" {
  default = "10.0.5.0/24"
}


# outputs


# logic

locals {
  db_subnet_id       = var.create_db_subnet ? module.DB-SN[0].subnet_id : null
}


# resource or mixed module blocks


module "DB-SN" {
  # TODO: change back to devrel project after pulling in my hotfix from my fork
  source = "github.com/JBAnderson5/terraform-oci-oracle-cloud-foundation//cloud-foundation/modules/cloud-foundation-library/network-subnet/module?ref=EBSsubmodules"
  count  = var.create_db_subnet ? 1 : 0

  # vcn info
  vcn                = local.vcn_id
  vcn_cidrs          = module.vcn[0].cidrs
  service_gateway_id = module.vcn[0].service_gateway
  service_cidr       = module.vcn[0].service_cidr
  network_gateway_id = module.vcn[0].nat_gateway

  # subnet specs
  compartment      = local.network_compartment
  prefix           = "${local.environment_prefix}-db"
  subnet_dns_label = "${var.ebs_workload_prefix}${var.ebs_workload_environment_name}db"
  internet_access  = "nat" #var.db_internet_access
  cidr_block       = var.db_subnet_cidr


  # tcp ingress ruless
  ssh_cidr = local.ssh_cidr
  custom_tcp_ingress_rules = merge(
    {
      self = {
        source_cidr = var.db_subnet_cidr,
        min         = 1521,
        max         = 1524,
      },
      self_ssh = {
        source_cidr = var.db_subnet_cidr,
        min         = 22,
        max         = 22,
      },
    },

    var.create_lb_app_subnets ?
    {
      apps = {
        source_cidr = var.apps_subnet_cidr,
        min         = 1521,
        max         = 1524,
      },
    } : {},

    var.create_ext_lb_app_subnets ?
    {
      ext-apps = {
        source_cidr = var.ext_apps_subnet_cidr,
        min         = 1521,
        max         = 1524,
      },
    } : {},

  )

  # tcp egress rules
  all_outbound_traffic = false
  custom_tcp_egress_rules = merge(
    {
      "self" = {
        dest_cidr = var.db_subnet_cidr,
        min       = 1521,
        max       = 1524,
      },
      "self_ssh" = {
        dest_cidr = var.db_subnet_cidr,
        min       = 22,
        max       = 22,
      },
    },

    var.create_cm_subnets ?
    {
      "cm_app" = {
        dest_cidr = var.cm_app_subnet_cidr,
        min       = 443,
        max       = 443,
      }
    } : {},
  )
  tcp_all_ports_egress_cidrs = ["134.70.0.0/17"]

  # icmp rules
  icmp_ingress_cidrs  = [var.cm_app_subnet_cidr, var.db_subnet_cidr, var.apps_subnet_cidr, var.ext_apps_subnet_cidr]
  icmp_egress_cidrs   = [local.anywhere]
  icmp_egress_service = true
}