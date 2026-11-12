# No output is sensitive and none holds the connect token. The `mctl cloud-account connect
# --from-terraform-output` fallback reads these values.

output "tenant_id" {
  description = "ID of the Microsoft Entra tenant of the identity."
  value       = azurerm_user_assigned_identity.provisioner.tenant_id
}

output "client_id" {
  description = "Client ID of the user-assigned managed identity that Multicloud signs in as."
  value       = azurerm_user_assigned_identity.provisioner.client_id
}

output "uami_resource_id" {
  description = "Azure resource ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.provisioner.id
}

output "principal_id" {
  description = "Object ID of the service principal of the identity."
  value       = azurerm_user_assigned_identity.provisioner.principal_id
}

output "role_definition_id" {
  description = "Resource ID of the custom role that the identity holds in your subscription."
  value       = azurerm_role_definition.provisioner.role_definition_resource_id
}

output "policy_version" {
  description = "Version of the permission bundle in this module release."
  value       = local.bundle.policy_version
}

output "module_version" {
  description = "Version of this module."
  value       = local.module_version
}
