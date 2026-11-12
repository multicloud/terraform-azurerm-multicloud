# One-time post-back: tells the Multicloud API the tenant, the client ID and the resource ID of the
# identity, the policy version and the module version. The module never sends a key or a secret.
#
# - The connect token reaches curl through the environment (MC_CONNECT_TOKEN) and a curl
#   config file on stdin. It is never an argument, so `ps` cannot show it.
# - triggers_replace holds only a hash of the token. A new token posts again.
# - Only an HTTP 2xx answer counts as success. On any other result the command prints the
#   server body and the fallback. Neither contains the token.
# - post_back = false creates no connect resource, so no curl runs.

resource "terraform_data" "connect" {
  count = var.post_back ? 1 : 0

  triggers_replace = [sha256(var.connect_token)]

  # Post only after the access exists: every credential and the role assignment.
  depends_on = [
    azurerm_federated_identity_credential.fic_0,
    azurerm_federated_identity_credential.fic_1,
    azurerm_federated_identity_credential.fic_2,
    azurerm_federated_identity_credential.fic_3,
    azurerm_role_assignment.provisioner,
  ]

  provisioner "local-exec" {
    environment = {
      MC_CONNECT_TOKEN = var.connect_token
      MC_URL           = "${trimsuffix(var.api_base, "/")}/api/v1/orgs/${var.org_slug}/cloud-accounts/${var.account_row_id}/connect"
      MC_BODY = jsonencode({
        tenant_id        = azurerm_user_assigned_identity.provisioner.tenant_id
        client_id        = azurerm_user_assigned_identity.provisioner.client_id
        uami_resource_id = azurerm_user_assigned_identity.provisioner.id
        policy_version   = local.bundle.policy_version
        module_version   = local.module_version
      })
    }

    # Only a 2xx answer counts as success. curl does not follow redirects (no -L), and
    # --fail-with-body fails only on 400 and above, so the script reads the status code (-w)
    # and the body goes to a temp file (-o). On any other result the script prints the body
    # and the fallback. In this HCL heredoc, %% writes a literal %.
    command = <<-EOT
      body_file="$(mktemp)" || exit 1
      trap 'rm -f "$body_file"' EXIT
      rc=0
      code="$(printf 'header = "X-Multicloud-Connect-Token: %s"\n' "$MC_CONNECT_TOKEN" | ${var.curl_command} --fail-with-body -sS -X POST -H "Content-Type: application/json" --data "$MC_BODY" -o "$body_file" -w '%%{http_code}' -K - "$MC_URL")" || rc=$?
      case "$code" in
        2??) [ "$rc" -eq 0 ] && exit 0 ;;
      esac
      cat "$body_file" >&2
      echo >&2
      echo "post-back failed (HTTP status: $${code:-none}); run: mctl cloud-account connect ${var.account_row_id} --from-terraform-output" >&2
      exit 1
    EOT
  }
}
