# The custom role and its assignment. The actions come only from policy.customer.json.
# The role grants no action that attaches an identity to a virtual machine.

resource "azurerm_role_definition" "provisioner" {
  name        = "MulticloudProvisioner-${local.hex}"
  scope       = local.scope
  description = "Actions that Multicloud may run in this subscription. Created by the Multicloud connect module."

  permissions {
    actions     = local.bundle.actions
    not_actions = []
  }

  assignable_scopes = [local.scope]
}

resource "azurerm_role_assignment" "provisioner" {
  scope              = local.scope
  role_definition_id = azurerm_role_definition.provisioner.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.provisioner.principal_id
  principal_type     = "ServicePrincipal"
}
