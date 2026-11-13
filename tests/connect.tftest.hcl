# Post-back tests. The azurerm provider is mocked and curl is replaced by tests/fake_curl.sh,
# so no network call happens. The local-exec provisioner does run, in the module directory.

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

variables {
  subscription_id   = "00000000-1111-2222-3333-444444444444"
  location          = "westeurope"
  multicloud_issuer = "https://issuer.example.com"
  audience          = "api://AzureADTokenExchange/mca-0123456789abcdef0123456789abcdef"
  api_base          = "https://api.example.com"
  org_slug          = "acme"
  account_row_id    = 42
  connect_token     = "mct-test-fixture-1"
  curl_command      = "FAKE_CURL_CAPTURE=./tests/.capture/calls.log ./tests/fake_curl.sh"
  federated_subjects = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
  ]
}

run "reset" {
  command = apply

  module {
    source = "./tests/reset"
  }

  variables {
    path = "./tests/.capture/calls.log"
  }
}

run "first_apply" {
  command = apply

  override_resource {
    target = random_id.suffix
    values = {
      hex = "a1b2c3d4"
    }
  }
}

run "post_back_body_has_exactly_five_keys" {
  command = plan

  module {
    source = "./tests/capture"
  }

  variables {
    path = "./tests/.capture/calls.log"
  }

  assert {
    condition     = output.calls == 1
    error_message = "the first apply must post exactly once"
  }

  assert {
    condition     = jsonencode(sort(keys(output.last_body))) == jsonencode(["client_id", "module_version", "policy_version", "tenant_id", "uami_resource_id"])
    error_message = "the body must hold exactly tenant_id, client_id, uami_resource_id, policy_version and module_version"
  }

  assert {
    condition     = output.last_body.tenant_id == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" && output.last_body.client_id == "11111111-2222-3333-4444-555555555555" && endswith(output.last_body.uami_resource_id, "/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mc-provisioner-a1b2c3d4")
    error_message = "the body values must come from the identity"
  }

  assert {
    condition     = output.last_body.module_version == "1.0.1" && tostring(output.last_body.policy_version) == "2"
    error_message = "the body must carry the module version and the policy version"
  }

  assert {
    condition     = !strcontains(output.argv, "mct-test-fixture-1") && output.last_token == "mct-test-fixture-1"
    error_message = "the token must reach curl only through the MC_CONNECT_TOKEN environment variable"
  }

  assert {
    condition     = output.last_url == "https://api.example.com/api/v1/orgs/acme/cloud-accounts/42/connect"
    error_message = "the URL is {api_base}/api/v1/orgs/{org_slug}/cloud-accounts/{account_row_id}/connect"
  }

  assert {
    condition     = output.last_stdin == "header = \"X-Multicloud-Connect-Token: mct-test-fixture-1\""
    error_message = "the token header must reach curl through its config file on stdin"
  }
}
