# Provider pins for the customer Azure connect module.
#
# - Exact provider versions, like the aws and gcp modules. azurerm matches the platform module
#   data/bootstrap/terraform/modules/azure-env.
# - required_version floor 1.10.0: the removed block with lifecycle (main.tf) needs OpenTofu 1.10
#   (Terraform 1.7). One floor serves both tools.
# - No provider block here: the caller configures the azurerm provider (credentials).
#   A module with its own provider block cannot be removed with `terraform destroy`
#   once the caller drops it.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}
