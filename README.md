# Uplapse website monitoring module

Watch a domain the way it usually needs watching, in one block: the website, its TLS certificate, the domain
registration and its email authentication, plus optional mail servers and scheduled-job heartbeats.
Built on the [Uplapse provider](https://registry.terraform.io/providers/uplapse/uplapse).

```hcl
module "example_com" {
  source  = "uplapse/website/uplapse"
  version = "~> 0.1"

  domain         = "example.com"
  alert_user_ids = [42]
}
```

That creates four monitors, named `example.com: …` and tagged `example.com`:

| Check | Monitor type | Default |
|---|---|---|
| The site answers (`url`, default `https://<domain>`); with `keyword`, the page contains it | `HTTPS` / `KEYWORD` | plan's shortest interval |
| The TLS certificate is valid and not about to expire | `TLS_CERT` | daily, fails at 14 days left |
| The domain registration is not about to expire | `DOMAIN_EXPIRY` | daily, fails at 30 days left |
| SPF and DMARC are published; optionally MTA-STS required and the mail servers' IPs off blacklists | `MAIL_AUTH` | hourly |

Each can be turned off with `checks = { email_auth = false }`.

## Mail servers and scheduled jobs

```hcl
module "acme" {
  source  = "uplapse/website/uplapse"
  version = "~> 0.1"

  domain = "acme.co.uk"
  email  = { required_mta_sts_mode = "enforce", check_blacklists = true }

  mail_servers = {
    mailbox = { host = "outlook.office365.com", protocol = "IMAPS" }
    relay   = { host = "smtp.acme.co.uk", protocol = "SUBMISSION" }
  }

  heartbeats = {
    nightly-backup = { interval = 86400, grace_seconds = 3600 }
  }
}

output "backup_ping" {
  value     = module.acme.heartbeat_urls["nightly-backup"]
  sensitive = true
}
```

Mail server checks read the greeting, set up TLS and check the certificate. To also check that logging in works,
add a username and password to the monitor in the app (Advanced > Authentication). Port 25 cannot be monitored: the
checking locations' cloud providers block it.

## Many domains

Agencies and MSPs can keep every client in one list; see [`examples/agency`](examples/agency/main.tf).

```hcl
module "client" {
  source   = "uplapse/website/uplapse"
  version  = "~> 0.1"
  for_each = toset(["acme.co.uk", "bakery.example", "shop.example"])

  domain                  = each.key
  alert_contact_group_ids = [7]
}
```

## Inputs

| Name | Description | Default |
|---|---|---|
| `domain` | Domain to watch, e.g. `example.com` (required) | |
| `url` | Address of the uptime check | `https://<domain>` |
| `name_prefix` | Prefix of monitor names (names must be unique in the organisation) | the domain |
| `checks` | `{ uptime, certificate, domain_expiry, email_auth }`, each on by default | all on |
| `keyword` | Text the page must contain (makes the uptime check a `KEYWORD` check) | `null` |
| `expected_status` | HTTP status the uptime check must get | any success |
| `interval` | Seconds between uptime checks | plan's shortest |
| `locations` | City ids for the uptime and mail server checks (`uplapse_locations` data source) | any available |
| `certificate_min_days` | Certificate warning, days | `14` |
| `domain_min_days` | Domain registration warning, days | `30` |
| `email` | `{ required_mta_sts_mode = "testing" \| "enforce", check_blacklists = bool }` | not required, off |
| `mail_servers` | Map of `{ host, protocol, port }`; protocol `SUBMISSION`, `SMTPS`, `IMAP`, `IMAPS`, `POP3`, `POP3S` | `{}` |
| `heartbeats` | Map of `{ interval, grace_seconds }` | `{}` |
| `tags` | Tags on every monitor (the domain is always added) | `[]` |
| `alert_user_ids` | Users alerted by every monitor; `null` keeps what is set in the app | `null` |
| `alert_contact_group_ids` | Contact groups alerted; `null` keeps what is set in the app | `null` |
| `paused` | Pause every monitor | `false` |

## Outputs

| Name | Description |
|---|---|
| `monitor_ids` | Monitor ids by check: `uptime`, `certificate`, `domain_expiry`, `email_auth`, `mail_<name>`, `job_<name>` |
| `heartbeat_urls` | Ping address of each heartbeat (sensitive) |

## Development

```sh
terraform fmt -check -recursive
terraform init -backend=false && terraform test       # unit tests, mocked provider
PROVIDER_DIR=../terraform-provider-uplapse tests/integration.sh   # real provider against its mock API
```

Until the provider is on the registry, point Terraform at a local build with `dev_overrides` (see the provider's
README, "Development").

## Publishing

The registry publishes modules from a public GitHub repository named `terraform-<provider>-<name>`: create
`uplapse/terraform-uplapse-website`, push `main`, add a licence, then in the registry choose **Publish > Module** and
tag `v0.1.0`. Publish the provider first: the module's tests need it from the registry.
