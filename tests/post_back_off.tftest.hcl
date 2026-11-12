# Post-back off test (own file, own state, own capture count). The azurerm provider is mocked and curl is replaced by tests/fake_curl.sh,
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

run "apply_without_post_back" {
  command = apply

  variables {
    post_back = false
  }

  override_resource {
    target = random_id.suffix
    values = {
      hex = "a1b2c3d4"
    }
  }
}

run "post_back_false_runs_no_curl" {
  command = plan

  module {
    source = "./tests/capture"
  }

  variables {
    path = "./tests/.capture/calls.log"
  }

  assert {
    condition     = output.calls == 0
    error_message = "post_back = false must not run curl"
  }
}
