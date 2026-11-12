# Changelog

## 1.0.0 - 2026-11-08

First release of the Azure connect module.

- Creates the resource group `mc-identity-<8 hex>` and the user-assigned managed identity `mc-provisioner-<8 hex>`. The identity has no key and no secret.
- Creates one federated identity credential for each item of `federated_subjects` (1 to 4). Each credential trusts only `multicloud_issuer`, one exact subject and the audience `audience`. The module creates the credentials one after the other, because Azure refuses two at the same time.
- Creates the custom role `MulticloudProvisioner-<8 hex>` from the permission bundle (`policy_version` 2) and assigns it to the identity at your subscription. The role holds no action that attaches an identity to a virtual machine.
- Registers the resource providers `Microsoft.Compute`, `Microsoft.Network`, `Microsoft.Quota` and `Microsoft.ManagedIdentity`.
- Posts `tenant_id`, `client_id`, `uami_resource_id`, `policy_version` and `module_version` once to the Multicloud API. A new `connect_token` posts again. Set `post_back = false` to skip the post.
