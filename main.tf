# The keyless path into a dedicated Azure subscription:
# AWS outbound web identity token -> federated identity credential -> user-assigned managed identity (UAMI)
# -> custom role at the subscription.
# The module creates no key, no secret and no identity on any virtual machine.

locals {
  module_version = "1.0.1"

  # policy.customer.json is generated from the Multicloud permission list. Do not edit by hand.
  bundle = jsondecode(file("${path.module}/policy.customer.json"))

  hex = random_id.suffix.hex

  scope = "/subscriptions/${var.subscription_id}"

  # Never the key multicloud:managed: Multicloud puts it on the resources that it creates.
  tags = var.tags
}

resource "random_id" "suffix" {
  byte_length = 4
}

# The prefix mc-identity- differs on purpose from the multicloud- prefix of the groups that Multicloud
# creates, so Multicloud never treats this group as its own.
resource "azurerm_resource_group" "identity" {
  name     = "mc-identity-${local.hex}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "provisioner" {
  name                = "mc-provisioner-${local.hex}"
  resource_group_name = azurerm_resource_group.identity.name
  location            = azurerm_resource_group.identity.location
  tags                = local.tags
}

# 1.0.0 managed the four resource provider registrations as resources. That failed for a namespace that was
# already registered, and destroy unregistered the namespaces in your subscription. The azurerm provider
# block now registers them (resource_providers_to_register, see the README). This block makes Terraform
# forget the old registrations on upgrade: it neither unregisters them nor deletes them.
removed {
  from = azurerm_resource_provider_registration.namespace

  lifecycle {
    destroy = false
  }
}
