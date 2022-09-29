# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# TODO: moved to security stack for now as this feature is being backlogged

# inputs 

variable "create_private_dns" {
  type = bool 
  default = false
  description = "if true, extends private vcn dns to include a new zone that routes using the dns name provided"
}

variable "domain_name" {
  type = string 
  default = "ebs.com"
  description = "the domain name used to create a new private dns zone"
}

variable "cm_host_name" {
  type = string 
  default = "cm"
  description = "the host name/subdomain to be used for cm dns"
}


variable "lb_ip" {
  default = null
}

/* expected defined values
  local.vcn_id - ocid

*/


# this gets the resolver from the vcn that was just created
# not guaranteed to be created at vcn creation time: Resolver will be created when vcn is created. But the creation happens asynchronously and may take longer because it is a background event that needs to run. The state will be PROVISIONING until the resolver is actually created. After the resolver is actually created, the state will be set to AVAILABLE. Users need to do a terraform refresh to poll and update the state file after sometime to get the dns_resolver_id and state AVAILABLE.
data "oci_core_vcn_dns_resolver_association" "ebs" {
  count = var.create_private_dns ? 1 : 0
    vcn_id = local.vcn_id
}

# this loads the resolver, which can then get the default system created view
data "oci_dns_resolver" "ebs" {
  count = var.create_private_dns ? 1 : 0
    resolver_id = data.oci_core_vcn_dns_resolver_association.ebs[0].dns_resolver_id
    scope = "PRIVATE"
}





# outputs

output "dns_status" {
  value = data.oci_core_vcn_dns_resolver_association.ebs[0].state != "AVAILABLE" ? "dns resolver still provisioning" : "dns resolver available"
}

output "FQDN" {
  value = local.ebscm_domain
}


# logic

locals {
  ebscm_domain = var.create_private_dns ? "${var.cm_host_name}.${oci_dns_zone.ebs[0].name}" : null


  lb_ip = var.lb_ip
}



# resource or mixed module blocks




# Can't add records to existing protected zone, so creating our own zone
resource "oci_dns_zone" "ebs" {
    count = var.create_private_dns ? 1 : 0
    compartment_id = local.network_compartment
    name = var.domain_name
    zone_type = "PRIMARY"
    scope = "PRIVATE"
    view_id = data.oci_dns_resolver.ebs[0].default_view_id 
}



resource "oci_dns_rrset" "this" {
  count = var.create_private_dns ? 1 : 0

  compartment_id = local.network_compartment
  domain = local.ebscm_domain
  rtype = "A"
  zone_name_or_id =  oci_dns_zone.ebs[0].id
  scope = "PRIVATE"

  items {
       domain = local.ebscm_domain
    rtype  = "A"
    rdata  = local.lb_ip
    ttl    = 3600
  }
  
}

