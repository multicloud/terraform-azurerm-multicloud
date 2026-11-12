variable "subscription_id" {
  description = "ID of your dedicated Azure subscription, as a lowercase GUID. Multicloud gets its role in this subscription only."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase GUID, for example 00000000-0000-0000-0000-000000000000."
  }
}

variable "location" {
  description = "Azure region of the resource group that holds the identity, for example westeurope. Multicloud acts in every region of the subscription."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.location))
    error_message = "location must be an Azure region name such as westeurope (lowercase letters and digits)."
  }
}

variable "multicloud_issuer" {
  description = "Issuer URL of the Multicloud web identity tokens. The Multicloud API returns it in the connect snippet."
  type        = string

  validation {
    condition     = can(regex("^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~/-]*)?$", var.multicloud_issuer))
    error_message = "multicloud_issuer must be an https:// URL with a host name and an optional plain path."
  }
}

variable "federated_subjects" {
  description = "Subjects (ARNs of the Multicloud broker roles) that may sign in as the identity. The Multicloud API returns them. Use 1 to 4 items. Each item becomes one federated credential."
  type        = list(string)

  validation {
    condition     = length(var.federated_subjects) >= 1 && length(var.federated_subjects) <= 4
    error_message = "federated_subjects must have 1 to 4 items."
  }

  validation {
    condition     = alltrue([for s in var.federated_subjects : can(regex("^arn:aws:iam::[0-9]{12}:role/multicloud-broker-[a-z0-9-]+$", s))])
    error_message = "Each federated_subjects item must look like arn:aws:iam::<12 digits>:role/multicloud-broker-<name>."
  }

  validation {
    condition     = length(distinct(var.federated_subjects)) == length(var.federated_subjects)
    error_message = "federated_subjects must not repeat an item."
  }
}

variable "audience" {
  description = "Audience of the web identity tokens. The Multicloud API generated it for this account. Format: api://AzureADTokenExchange/mca- and 32 hex characters."
  type        = string

  validation {
    condition     = can(regex("^api://AzureADTokenExchange/mca-[0-9a-f]{32}$", var.audience))
    error_message = "audience must be api://AzureADTokenExchange/mca- followed by 32 lowercase hex characters."
  }
}

variable "api_base" {
  description = "Base URL of the Multicloud API, for example https://api.multicloud.io. The module posts the connection data there once."
  type        = string

  validation {
    condition     = can(regex("^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~/-]*)?$", var.api_base))
    error_message = "api_base must be an https:// URL with a host name and an optional plain path."
  }
}

variable "org_slug" {
  description = "Your organization slug, as the Multicloud API shows it."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.org_slug))
    error_message = "org_slug may contain only letters, digits, dot, underscore and hyphen."
  }
}

variable "account_row_id" {
  description = "Number of the cloud account row that the Multicloud API created for this subscription."
  type        = number

  validation {
    condition     = var.account_row_id > 0 && var.account_row_id == floor(var.account_row_id)
    error_message = "account_row_id must be a positive whole number."
  }
}

variable "connect_token" {
  description = "One-time token that the Multicloud API generated. The module sends it once, in an HTTP header, to confirm the connection. A new token makes the module post again. The token may contain only the characters A-Z a-z 0-9 and ._~+/=:- (the module writes it into a curl config line)."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9._~+/=:-]+$", var.connect_token))
    error_message = "connect_token has characters outside A-Z a-z 0-9 and ._~+/=:-. Copy it again from the API response."
  }
}

variable "post_back" {
  description = "Set to false to skip the post to the Multicloud API. Then run the command that the README shows (mctl cloud-account connect --from-terraform-output)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags for the resource group and the identity. Do not use the key multicloud:managed: Multicloud uses it for resources that it creates."
  type        = map(string)
  default     = {}

  validation {
    condition     = !contains(keys(var.tags), "multicloud:managed")
    error_message = "tags must not use the key multicloud:managed."
  }
}

variable "curl_command" {
  description = "TEST ONLY. The command that sends the post-back. Leave the default, curl. The module tests replace it with a test double."
  type        = string
  default     = "curl"

  # The value runs in a shell: allow only curl or the module's own test double.
  validation {
    condition     = can(regex("^(curl|(FAKE_CURL_CAPTURE=[A-Za-z0-9._/-]+ )?\\./tests/fake_curl\\.sh)$", var.curl_command))
    error_message = "curl_command is for the module tests only. Leave the default, curl."
  }
}
