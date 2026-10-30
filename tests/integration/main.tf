# Used by tests/integration.sh: the module through the real provider against the provider's mock API.
terraform {
  required_providers {
    uplapse = {
      source = "uplapse/uplapse"
    }
  }
}

variable "endpoint" { type = string }
variable "api_key" {
  type      = string
  sensitive = true
}
variable "keyword" {
  type    = string
  default = null
}
variable "mailbox_protocol" {
  type    = string
  default = "IMAPS"
}

provider "uplapse" {
  endpoint = var.endpoint
  api_key  = var.api_key
}

module "site" {
  source = "../.."

  domain         = "example.com"
  keyword        = var.keyword
  locations      = [2643743, 2925533]
  email          = { required_mta_sts_mode = "enforce", check_blacklists = true }
  mail_servers   = { mailbox = { host = "imap.example.com", protocol = var.mailbox_protocol } }
  heartbeats     = { backup = { interval = 86400 } }
  tags           = ["it"]
  alert_user_ids = []
}

module "other" {
  source = "../.."

  domain = "example.org"
  checks = { email_auth = false }
}

output "ids" { value = merge(module.site.monitor_ids, { for k, v in module.other.monitor_ids : "other_${k}" => v }) }
output "ping" {
  value     = module.site.heartbeat_urls
  sensitive = true
}
