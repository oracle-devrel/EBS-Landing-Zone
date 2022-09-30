# Copyright © 2022, Oracle and/or its affiliates.
# All rights reserved. Licensed under the Universal Permissive License (UPL), Version 1.0 as shown at https://oss.oracle.com/licenses/upl.


# inputs

/* expected defined values
local.vault - ocid

*/

# outputs


# logic


# resource or mixed module blocks



data "oci_kms_vault" "this" {
  vault_id = local.vault
}

resource "oci_kms_key" "CAMasterKey" {
  compartment_id = local.security_compartment
  display_name = "CA Cert Key"
  key_shape {
    algorithm = "RSA"
    length = 256
  }

  management_endpoint = data.oci_kms_vault.this.management_endpoint
  protection_mode = "HSM" #required for CA keys
}

/*
resource "oci_kms_generated_key" "CAAlgoKey" {
    #Required
    crypto_endpoint = data.oci_kms_vault.this.crypto_endpoint
    include_plaintext_key = false
    key_id = oci_kms_key.CAMasterKey.id
    key_shape {
        #Required
        algorithm = "RSA"
        length = "256"
    }
}
*/