# Offline tests: the azurerm provider is mocked, nothing reaches Azure.
# Run from deploy/customer-terraform/azure: tofu init -backend=false && tofu test

mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-1111-2222-3333-444444444444/resourceGroups/mc-identity-a1b2c3d4/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mc-provisioner-a1b2c3d4"
      tenant_id    = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
      client_id    = "11111111-2222-3333-4444-555555555555"
      principal_id = "99999999-8888-7777-6666-555555555555"
    }
  }
  mock_resource "azurerm_role_definition" {
    defaults = {
      role_definition_resource_id = "/subscriptions/00000000-1111-2222-3333-444444444444/providers/Microsoft.Authorization/roleDefinitions/12345678-1234-1234-1234-123456789012"
    }
  }
}

override_resource {
  target = random_id.suffix
  values = {
    hex = "a1b2c3d4"
  }
}

variables {
  subscription_id   = "00000000-1111-2222-3333-444444444444"
  location          = "westeurope"
  multicloud_issuer = "https://issuer.example.com"
  audience          = "api://AzureADTokenExchange/mca-0123456789abcdef0123456789abcdef"
  api_base          = "https://api.example.com"
  org_slug          = "acme"
  account_row_id    = 42
  connect_token     = "tok-placeholder"
  curl_command      = "FAKE_CURL_CAPTURE=./tests/.capture/module.log ./tests/fake_curl.sh"
  federated_subjects = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-api",
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-catalog",
  ]
}

run "fic_per_subject_exact_subject_and_audience" {
  command = plan

  assert {
    condition     = length(azurerm_federated_identity_credential.fic_0) == 1 && length(azurerm_federated_identity_credential.fic_1) == 1 && length(azurerm_federated_identity_credential.fic_2) == 1 && length(azurerm_federated_identity_credential.fic_3) == 0
    error_message = "three subjects must make exactly fic_0, fic_1 and fic_2"
  }

  assert {
    condition = (
      azurerm_federated_identity_credential.fic_0[0].subject == var.federated_subjects[0] &&
      azurerm_federated_identity_credential.fic_1[0].subject == var.federated_subjects[1] &&
      azurerm_federated_identity_credential.fic_2[0].subject == var.federated_subjects[2]
    )
    error_message = "each credential subject must be the broker ARN, copied unchanged"
  }

  assert {
    condition = alltrue([
      for f in concat(azurerm_federated_identity_credential.fic_0, azurerm_federated_identity_credential.fic_1, azurerm_federated_identity_credential.fic_2) :
      f.issuer == "https://issuer.example.com" && jsonencode(f.audience) == jsonencode(["api://AzureADTokenExchange/mca-0123456789abcdef0123456789abcdef"])
    ])
    error_message = "issuer must be multicloud_issuer and audience must be exactly [audience]"
  }
}

run "four_subjects_make_four_credentials" {
  command = plan

  variables {
    federated_subjects = [
      "arn:aws:iam::111122223333:role/multicloud-broker-a",
      "arn:aws:iam::111122223333:role/multicloud-broker-b",
      "arn:aws:iam::111122223333:role/multicloud-broker-c",
      "arn:aws:iam::111122223333:role/multicloud-broker-d",
    ]
  }

  assert {
    condition     = length(azurerm_federated_identity_credential.fic_3) == 1 && azurerm_federated_identity_credential.fic_3[0].subject == "arn:aws:iam::111122223333:role/multicloud-broker-d"
    error_message = "four subjects must make fic_3"
  }
}

# Sequential creates: tofu test cannot read the dependency graph, so this is a static check of
# fic.tf. Each block after the first must hold depends_on = [<previous block>] and nothing else.
run "fics_are_created_sequentially" {
  command = plan

  assert {
    condition = alltrue([
      for i in [1, 2, 3] :
      can(regex(format("resource \"azurerm_federated_identity_credential\" \"fic_%d\" \\{[^}]*depends_on = \\[azurerm_federated_identity_credential\\.fic_%d\\]", i, i - 1), file("fic.tf")))
    ]) && length(var.org_slug) > 0
    error_message = "fic_1, fic_2 and fic_3 must each depend on the previous credential"
  }

  assert {
    condition     = !can(regex("resource \"azurerm_federated_identity_credential\" \"fic_0\" \\{[^}]*depends_on", file("fic.tf"))) && length(regexall("resource \"azurerm_federated_identity_credential\"", file("fic.tf"))) == 4 && length(var.org_slug) > 0
    error_message = "fic.tf must hold exactly 4 credential resources, and the first has no depends_on"
  }

  assert {
    condition     = !can(regex("for_each", file("fic.tf"))) && length(var.org_slug) > 0
    error_message = "a for_each would create the credentials in parallel"
  }
}

run "role_actions_equal_policy_file" {
  command = plan

  assert {
    condition     = jsonencode(sort(azurerm_role_definition.provisioner.permissions[0].actions)) == jsonencode(sort(jsondecode(file("policy.customer.json")).actions)) && length(azurerm_role_definition.provisioner.permissions[0].actions) > 0
    error_message = "role actions must equal the actions of policy.customer.json"
  }

  assert {
    condition     = azurerm_role_definition.provisioner.name == "MulticloudProvisioner-a1b2c3d4" && jsonencode(azurerm_role_definition.provisioner.assignable_scopes) == jsonencode(["/subscriptions/00000000-1111-2222-3333-444444444444"]) && azurerm_role_definition.provisioner.scope == "/subscriptions/00000000-1111-2222-3333-444444444444"
    error_message = "the role must be assignable at the subscription only"
  }
}

run "role_assigned_at_subscription_to_uami_principal" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.provisioner.scope == "/subscriptions/00000000-1111-2222-3333-444444444444" && azurerm_role_assignment.provisioner.principal_id == "99999999-8888-7777-6666-555555555555"
    error_message = "the role must be assigned at the subscription to the principal of the identity"
  }
}

run "names_and_tags" {
  command = plan

  assert {
    condition     = azurerm_resource_group.identity.name == "mc-identity-a1b2c3d4" && azurerm_user_assigned_identity.provisioner.name == "mc-provisioner-a1b2c3d4" && !startswith(azurerm_resource_group.identity.name, "multicloud-")
    error_message = "resource group and identity names must follow the mc-identity-/mc-provisioner- scheme"
  }

  assert {
    condition     = !contains(keys(azurerm_resource_group.identity.tags), "multicloud:managed") && !contains(keys(azurerm_user_assigned_identity.provisioner.tags), "multicloud:managed")
    error_message = "no resource may carry the tag multicloud:managed"
  }

}

# 1.0.1: the module manages no resource provider registration. A managed registration failed on a namespace
# that was already registered and unregistered the namespace on destroy. The provider block of the caller
# registers the namespaces (resource_providers_to_register); the removed block forgets the 1.0.0 resources.
run "no_managed_provider_registration" {
  command = plan

  assert {
    condition = alltrue([
      for f in fileset(".", "*.tf") : !can(regex("(?m)^resource\\s+\"azurerm_resource_provider_registration\"", file(f)))
    ]) && length(var.org_slug) > 0
    error_message = "no .tf file may declare an azurerm_resource_provider_registration resource"
  }

  assert {
    condition     = can(regex("(?s)removed\\s*\\{\\s*from\\s*=\\s*azurerm_resource_provider_registration\\.namespace\\s*lifecycle\\s*\\{\\s*destroy\\s*=\\s*false", file("main.tf"))) && length(var.org_slug) > 0
    error_message = "main.tf must forget the 1.0.0 registrations with removed { lifecycle { destroy = false } }"
  }
}

run "no_identity_attached_to_any_vm" {
  command = plan

  assert {
    condition = alltrue([
      for f in fileset(".", "*.tf") : !strcontains(lower(file(f)), "userassignedidentities/assign/action")
    ]) && !contains([for a in jsondecode(file("policy.customer.json")).actions : lower(a)], "microsoft.managedidentity/userassignedidentities/assign/action") && length(var.org_slug) > 0
    error_message = "no .tf file and no policy action may hold userAssignedIdentities/assign/action"
  }

  assert {
    condition     = alltrue([for f in fileset(".", "*.tf") : !can(regex("azurerm_(linux|windows)_virtual_machine|azurerm_virtual_machine|identity_ids", file(f)))]) && length(var.org_slug) > 0
    error_message = "the module must not declare a virtual machine or attach an identity to one"
  }
}

run "terraform_has_no_literal_action" {
  command = plan

  # Namespaces such as "Microsoft.Compute" (no slash) may appear as strings; actions may not.
  assert {
    condition     = alltrue([for f in fileset(".", "*.tf") : !can(regex("\"Microsoft\\.[A-Za-z]+/", file(f)))]) && length(var.org_slug) > 0
    error_message = "no .tf file may hold an action string such as \"Microsoft.X/y/z\""
  }
}

run "subscription_id_must_be_lowercase_guid" {
  command = plan

  variables {
    subscription_id = "00000000-1111-2222-3333-44444444444A"
  }

  expect_failures = [var.subscription_id]
}

run "audience_must_match_prefix" {
  command = plan

  variables {
    audience = "api://AzureADTokenExchange/other-0123456789abcdef0123456789abcdef"
  }

  expect_failures = [var.audience]
}

run "audience_must_have_32_hex" {
  command = plan

  variables {
    audience = "api://AzureADTokenExchange/mca-0123"
  }

  expect_failures = [var.audience]
}

run "federated_subjects_limits" {
  command = plan

  variables {
    federated_subjects = []
  }

  expect_failures = [var.federated_subjects]
}

run "tag_multicloud_managed_refused" {
  command = plan

  variables {
    tags = { "multicloud:managed" = "true" }
  }

  expect_failures = [var.tags]
}
