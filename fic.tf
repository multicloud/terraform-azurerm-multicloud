# One federated identity credential per broker role. Azure answers 409 when two credentials of
# one identity are created at the same time. A chain of depends_on keeps the creates strictly
# sequential. Terraform cannot express a chain over count or a map, so the module declares
# 4 explicit resources. Each one exists only when federated_subjects has enough items.
# The subject is the broker role ARN, copied unchanged.

resource "azurerm_federated_identity_credential" "fic_0" {
  count = length(var.federated_subjects) > 0 ? 1 : 0

  name                      = "mc-broker-0"
  user_assigned_identity_id = azurerm_user_assigned_identity.provisioner.id
  issuer                    = var.multicloud_issuer
  subject                   = var.federated_subjects[0]
  audience                  = [var.audience]
}

resource "azurerm_federated_identity_credential" "fic_1" {
  count = length(var.federated_subjects) > 1 ? 1 : 0

  name                      = "mc-broker-1"
  user_assigned_identity_id = azurerm_user_assigned_identity.provisioner.id
  issuer                    = var.multicloud_issuer
  subject                   = var.federated_subjects[1]
  audience                  = [var.audience]

  depends_on = [azurerm_federated_identity_credential.fic_0]
}

resource "azurerm_federated_identity_credential" "fic_2" {
  count = length(var.federated_subjects) > 2 ? 1 : 0

  name                      = "mc-broker-2"
  user_assigned_identity_id = azurerm_user_assigned_identity.provisioner.id
  issuer                    = var.multicloud_issuer
  subject                   = var.federated_subjects[2]
  audience                  = [var.audience]

  depends_on = [azurerm_federated_identity_credential.fic_1]
}

resource "azurerm_federated_identity_credential" "fic_3" {
  count = length(var.federated_subjects) > 3 ? 1 : 0

  name                      = "mc-broker-3"
  user_assigned_identity_id = azurerm_user_assigned_identity.provisioner.id
  issuer                    = var.multicloud_issuer
  subject                   = var.federated_subjects[3]
  audience                  = [var.audience]

  depends_on = [azurerm_federated_identity_credential.fic_2]
}
