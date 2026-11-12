# Multicloud Azure connect module

This Terraform module connects one Azure subscription to Multicloud.
It creates an identity that Multicloud signs in as.
It creates no key and no secret.

## What you need

- An Azure subscription for Multicloud. A new subscription made only for Multicloud is strongly recommended.
  A subscription that already holds virtual machines connects only after an organization owner approves it
  (`SUBSCRIPTION_NOT_DEDICATED`; `mctl cloud-account accept-shared-account <id>`).
- An identity that runs `apply` and is Owner of the subscription,
  or holds both User Access Administrator and Contributor.
- Terraform 1.6.0 or later, or OpenTofu 1.6.0 or later.
- The `hashicorp/azurerm` provider 5.12.0, configured by you (for example with `az login`).
- `curl` 7.76.0 or later in the `PATH`.
- A Linux or macOS shell (`/bin/sh`). Windows needs WSL.
- Network access from the machine that runs `apply` to the Multicloud API.

## What the module creates

- The resource group `mc-identity-<8 hex>` and the identity `mc-provisioner-<8 hex>` (a user-assigned managed identity).
- One federated credential for each item of `federated_subjects`.
  Each credential lets one Multicloud broker role sign in as the identity.
  The credential accepts only the issuer `multicloud_issuer` and the audience `audience`.
- The role `MulticloudProvisioner-<8 hex>` in your subscription, assigned to the identity.
  - The actions come from the permission bundle in `policy.customer.json`. The file is generated. Do not edit it.
  - The role cannot attach an identity to a virtual machine.
- The resource provider registrations `Microsoft.Compute`, `Microsoft.Network`, `Microsoft.Quota` and `Microsoft.ManagedIdentity`.
- One call to the Multicloud API, after the access exists.
  The call sends `tenant_id`, `client_id`, `uami_resource_id`, `policy_version` and `module_version`.
  The call sends the connect token in an HTTP header.

## What the module never creates

- No client secret, no certificate and no key.
- No identity on a virtual machine.
- No output holds the connect token.

## Use

`mctl cloud-account create` (or the Multicloud API) returns a ready snippet with every value filled in.
The snippet looks like the example in `../examples/azure/main.tf`. All values there are placeholders.

Set `resource_provider_registrations = "none"` in your `azurerm` provider block.
The module registers the four resource providers that it needs.
UNVERIFIED: if you do not set this value, `apply` may fail for a provider that is already registered.
If `apply` fails for this reason, import the registration or remove it from the module call, and run `apply` again.

## Inputs

| Name | Meaning |
|---|---|
| `subscription_id` | ID of your dedicated subscription (lowercase GUID). |
| `location` | Region of the resource group that holds the identity. |
| `multicloud_issuer` | Issuer URL of the Multicloud tokens. The snippet fills it. |
| `federated_subjects` | 1 to 4 Multicloud broker role ARNs. |
| `audience` | Audience of the tokens, `api://AzureADTokenExchange/mca-<32 hex>`. |
| `org_slug`, `account_row_id`, `api_base` | Where the module posts the connection data. |
| `connect_token` | One-time token (sensitive). |
| `post_back` | `true` (default) posts to the API. `false` skips the post. |
| `tags` | Extra tags. The key `multicloud:managed` is not allowed. |

## Outputs

`tenant_id`, `client_id`, `uami_resource_id`, `principal_id`, `role_definition_id`, `policy_version`, `module_version`.
The command `mctl cloud-account connect <id> --from-terraform-output` reads them when the post fails or when `post_back` is `false`.

## Keep the Terraform state

The state records what the module created. Keep the folder and its state file.

## Remove access

Run `terraform destroy`.
Terraform deletes the role assignment, the role, the credentials, the identity and the resource group.
Multicloud then cannot sign in to your subscription.

## Versions

Each release has a version tag `v<module_version>`.
Pin the version with the `version` argument of the module block.
The changes of each release are in `CHANGELOG.md`.

## Tests

`tofu init -backend=false && tofu test`. The tests use mock providers and make no cloud call.

## License

Apache-2.0. See `LICENSE`.
