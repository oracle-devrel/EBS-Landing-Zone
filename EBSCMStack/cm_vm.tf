# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.

# inputs




variable "instance_shape" {
  default = "VM.Standard2.1"
}

variable "instance_ssh_public_key" {

}

variable "password" {
  default = "WElcome##12345"
  type = string 
  description = "The password for the EBS CM Admin. Note: The password should contain at least one of these special characters: _ (underscore), # (hash), or $ (dollar). This password is used by the Oracle E-Business Suite Cloud Manager administrator to connect to the Cloud Manager database, and to run subsequent scripts."
  sensitive = true
}

variable "instance_ad" {

}
data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}
locals {
  ad_id = [for ad in data.oci_identity_availability_domains.this.availability_domains :
    ad.id
    if ad.name == var.instance_ad
  ][0]
}


# IDCS
variable "client_id" {
}
variable "client_secret" {
}
variable "client_tenant" {
}



#network zone lookup
data "oci_core_vcn" "this" {
  vcn_id = local.vcn_id
}
data "oci_core_subnet" "cm" {
  #Required
  subnet_id = local.cm_app_subnet_id
}
data "oci_core_subnet" "lb" {
  #Required
  subnet_id = local.lb_subnet_id
}
data "oci_core_subnet" "apps" {
  #Required
  subnet_id = local.apps_subnet_id
}
data "oci_core_subnet" "db" {
  #Required
  subnet_id = local.db_subnet_id
}



# EBS CM marketplace and image lookup
data "oci_core_app_catalog_listings" "ebscm" {
  filter {
    name   = "display_name"
    values = ["Oracle E-Business Suite Cloud Manager"]
  }
}
data "oci_core_app_catalog_listing_resource_versions" "ebscm" {
  listing_id = data.oci_core_app_catalog_listings.ebscm.app_catalog_listings[0]["listing_id"]
}

# IAM lookup
variable "cm_user_ocid" {
  type = string 
  default = null 
  description = "ocid of a local IAM user to associate with the cloud manager. if omitted, the ocid of the user who runs this stack will be used. This needs to be a local (non-federated) IAM user though"
  
}
locals {
  user_ocid = var.cm_user_ocid != null ? var.cm_user_ocid : var.current_user_ocid
}
data "oci_identity_tenancy" "tenancy" {
  tenancy_id = var.tenancy_ocid
}
data "oci_identity_user" "this" {
    user_id = local.user_ocid
}
data "oci_identity_group" "ebs_cm_admin_group" {
  group_id = local.cm_admin_group
}
data "oci_identity_compartment" "cm" {
  id = local.cm_compartment
}



# API key
variable "user_api_private_key" {
  type        = string
  default     = ""
  description = "The private api key associated with an EBSCM Admin user. If blank, a key will be generated for you and associated with your account"
  sensitive = true
}


data "oci_load_balancer_load_balancers" "this" {
  compartment_id = local.network_compartment


   filter {
    name   = "id"
    values = [local.lb_id]
    #regex  = true
  }
}





# outputs

/*
output "instance_private_ip" {
  value = oci_core_instance.ebscm.private_ip
}

output "instance_public_ip" {
  value = oci_core_instance.ebscm.public_ip
}
*/

output "ebscm_login_url" {
  value = "https://${var.cm_hostname}"
}

output "test" {
  value = "placeholder"
}

# logic 

locals {

  

  bootinfo = jsonencode({
    "serverHost"          = "${var.cm_hostname}",
    "clientId"            = "${var.client_id}",
    "clientSecret"        = "${var.client_secret}",
    "clientTenant"        = "${var.client_tenant}",
    "idcsHost"            = "https://${var.client_tenant}.identity.oraclecloud.com",
    "audienceServiceUrl"  = "https://${var.client_tenant}.identity.oraclecloud.com",
    "tenancyName"         = "${data.oci_identity_tenancy.tenancy.name}",
    "tenancyOcid"         = "${var.tenancy_ocid}",
    "username"            = "${data.oci_identity_user.this.name}",
    "userocid"            = "${local.user_ocid}",
    "groupname"           = "${data.oci_identity_group.ebs_cm_admin_group.name}",
    "groupocid"           = "${local.cm_admin_group}",
    "region"              = "${var.region}",
    "vcnName"             = "${data.oci_core_vcn.this.display_name}",
    "vcnOcid"             = "${local.vcn_id}",
    "vcnCidr"             = "${data.oci_core_vcn.this.cidr_block}", #cidr_block is depreciated, but not sure CM can handle new list of cidr_blocks 
    "ebscmSubnetName"     = "${data.oci_core_subnet.cm.display_name}",
    "ebscmSubnetOcid"     = "${local.cm_app_subnet_id}",
    "ebscmSubnetCidr"     = "${data.oci_core_subnet.cm.cidr_block}",
    "appsSubnetName"      = "${data.oci_core_subnet.apps.display_name}",
    "appsSubnetOcid"      = "${local.apps_subnet_id}",
    "appsSubnetCidr"      = "${data.oci_core_subnet.apps.cidr_block}",
    "dbSubnetName"        = "${data.oci_core_subnet.db.display_name}",
    "dbSubnetOcid"        = "${local.db_subnet_id}",
    "dbSubnetCidr"        = "${data.oci_core_subnet.db.cidr_block}",
    "lbaasSubnetName"     = "${data.oci_core_subnet.lb.display_name}",
    "lbaasName"           = "${data.oci_load_balancer_load_balancers.this.display_name}",
    "lbaasSubnetOcid"     = "${local.lb_subnet_id}",
    "lbaasSubnetCidr"     = "${data.oci_core_subnet.lb.cidr_block}",
    "compartmentName"     = "${data.oci_identity_compartment.cm.name}", # TODO: EBS compartment for lbaas, app and db tier
    "compartmentOcid"     = "${local.cm_compartment}",
    "adName"              = "${var.instance_ad}",
    "adOcid"              = "${local.ad_id}",
    "fingerprint"         = "FINGER__PRINT",  # TODO: use tls key
    "generateUserProfile" = "yes"   # TODO - give option based on importing keys
  })
}


# resource or mixed module blocks


# RM only supports TLS version 3.1.0 https://registry.terraform.io/providers/hashicorp/tls/3.1.0/docs/resources/private_key
# TODO - look to go back to local-exec with openssh for security
resource "tls_private_key" "api-key" {
  count = length(var.user_api_private_key) == 0 ? 1 : 0
  algorithm   = "RSA"
  rsa_bits  = 2048
}
resource "oci_identity_api_key" "api-key1" {
  count      = length(var.user_api_private_key) == 0 ? 1 : 0
  # provider   = oci.home
  user_id   = local.user_ocid
  key_value = tls_private_key.api-key[0].public_key_pem

  lifecycle {
    ignore_changes = [key_value]
  }
}

# TODO: add dependency for this resource
resource "null_resource" "validate-idcs" {
  provisioner "local-exec" {
    command = "code=$(curl -k -sS -X POST -u ${var.client_id}:${var.client_secret} -H 'Accept: */*' -H 'Cache-Control: no-cache, no-store,must-revalidate' -H 'Content-Type: application/x-www-form-urlencoded' https://${var.client_tenant}.identity.oraclecloud.com/oauth2/v1/introspect -d 'token=abcd' -w \"%%{http_code}\" -o /dev/null); if [[ $code != 200 ]]; then echo ERROR: IDCS Validations failed; exit 1; fi"
  }
}


resource "oci_core_app_catalog_listing_resource_version_agreement" "ebscm" {
  listing_id               = data.oci_core_app_catalog_listing_resource_versions.ebscm.app_catalog_listing_resource_versions[0]["listing_id"]
  listing_resource_version = data.oci_core_app_catalog_listing_resource_versions.ebscm.app_catalog_listing_resource_versions[0]["listing_resource_version"]
}

resource "oci_core_app_catalog_subscription" "ebscm" {
  compartment_id           = local.cm_compartment
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.ebscm.eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.ebscm.listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.ebscm.listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.ebscm.oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.ebscm.signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.ebscm.time_retrieved

  timeouts {
    create = "20m"
  }
}

data "oci_core_app_catalog_subscriptions" "ebscm" {
  compartment_id = local.cm_compartment
  listing_id     = oci_core_app_catalog_subscription.ebscm.listing_id

  filter {
    name   = "listing_resource_version"
    values = [oci_core_app_catalog_subscription.ebscm.listing_resource_version]
  }
}


# EBS - CM Instance
resource "oci_core_instance" "ebscm" {

  availability_domain = var.instance_ad
  compartment_id      = local.cm_compartment
  display_name        = "ebscm"
  shape               = var.instance_shape

  create_vnic_details {
    subnet_id        = local.cm_app_subnet_id
    assign_public_ip = false
    #hostname_label   = "ebscm"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_app_catalog_subscriptions.ebscm.app_catalog_subscriptions[0]["listing_resource_id"]
  }

  metadata = {
    ssh_authorized_keys = var.instance_ssh_public_key
    user_data = base64encode(
      templatefile("./bootstrap.tftpl", {
        password         = base64encode(var.password)
        bootinfo         = local.bootinfo,
        generate_profile = "yes", # TODO - create option
        user_name        = data.oci_identity_user.this.name,
        private_key      = length(var.user_api_private_key) > 0 ? var.user_api_private_key : tls_private_key.api-key[0].private_key_pem 
        passwd           = "$${passwd}" #passing interpolation through to instance
        }
    ))
  }

  timeouts {
    create = "60m"
  }

  provisioner "local-exec" {
    command = "sleep 600"
  }
}



