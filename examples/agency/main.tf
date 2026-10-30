# An agency or MSP watching every client's domain the same way, from one list. Adding a client is one line.

terraform {
  required_providers {
    uplapse = {
      source = "uplapse/uplapse"
    }
  }
}

provider "uplapse" {}

data "uplapse_locations" "all" {}

locals {
  london    = one([for c in data.uplapse_locations.all.locations : c.id if c.name == "London"])
  frankfurt = one([for c in data.uplapse_locations.all.locations : c.id if c.name == "Frankfurt am Main"])

  clients = {
    "acme.co.uk" = {
      keyword      = "Acme"
      mail_servers = { mailbox = { host = "outlook.office365.com", protocol = "IMAPS" } }
    }
    "bakery.example" = {}
    "shop.example" = {
      keyword    = "Add to basket"
      heartbeats = { "nightly-backup" = { interval = 86400, grace_seconds = 3600 } }
    }
  }
}

module "client" {
  source   = "uplapse/website/uplapse"
  version  = "~> 0.1"
  for_each = local.clients

  domain                  = each.key
  keyword                 = try(each.value.keyword, null)
  locations               = [local.london, local.frankfurt]
  email                   = { required_mta_sts_mode = null, check_blacklists = true }
  mail_servers            = try(each.value.mail_servers, {})
  heartbeats              = try(each.value.heartbeats, {})
  tags                    = ["client"]
  alert_contact_group_ids = [7]
}

output "heartbeat_urls" {
  value     = { for k, m in module.client : k => m.heartbeat_urls }
  sensitive = true
}
