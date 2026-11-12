# The keyless path into a dedicated Azure subscription:
# AWS outbound web identity token -> federated identity credential -> user-assigned managed identity (UAMI)
# -> custom role at the subscription.
# The module creates no key, no secret and no identity on any virtual machine.

locals {
  module_version = "1.0.0"

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

# UNVERIFIED: whether the apply fails for a namespace that is already registered. Set
# resource_provider_registrations = "none" on the azurerm provider (the example does) so the provider
# does not register them first.
resource "azurerm_resource_provider_registration" "namespace" {
  for_each = toset(["Microsoft.Compute", "Microsoft.Network", "Microsoft.Quota", "Microsoft.ManagedIdentity"])

  name = each.value
}
