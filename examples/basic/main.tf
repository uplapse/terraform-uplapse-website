# Uptime, certificate, domain registration and email authentication for one domain, alerting one user.
#
#   export UPLAPSE_API_KEY=...   # Settings > API keys in the app
#   terraform init && terraform apply

terraform {
  required_providers {
    uplapse = {
      source = "uplapse/uplapse"
    }
  }
}

provider "uplapse" {}

module "example_com" {
  source  = "uplapse/website/uplapse"
  version = "~> 0.1"

  domain         = "example.com"
  alert_user_ids = [42]
}

output "monitor_ids" {
  value = module.example_com.monitor_ids
}
