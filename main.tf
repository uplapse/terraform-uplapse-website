locals {
  domain = lower(var.domain)
  prefix = coalesce(var.name_prefix, local.domain)
  url    = coalesce(var.url, "https://${local.domain}")
  tags   = setunion(var.tags, [local.domain])
}

# Is the site up: the page answers (and contains var.keyword, when set).
resource "uplapse_monitor" "uptime" {
  count = var.checks.uptime ? 1 : 0

  name                    = "${local.prefix}: website"
  type                    = var.keyword == null ? "HTTPS" : "KEYWORD"
  url                     = local.url
  keyword                 = var.keyword
  expected_status         = var.expected_status
  interval                = var.interval
  locations               = var.locations
  tags                    = local.tags
  alert_user_ids          = var.alert_user_ids
  alert_contact_group_ids = var.alert_contact_group_ids
  paused                  = var.paused
}

# The TLS certificate: valid, trusted and not about to expire. Daily is enough.
resource "uplapse_monitor" "certificate" {
  count = var.checks.certificate ? 1 : 0

  name                    = "${local.prefix}: certificate"
  type                    = "TLS_CERT"
  url                     = local.domain
  min_tls_days_left       = var.certificate_min_days
  interval                = 86400
  tags                    = local.tags
  alert_user_ids          = var.alert_user_ids
  alert_contact_group_ids = var.alert_contact_group_ids
  paused                  = var.paused
}

# The domain registration, read from RDAP/WHOIS once a day.
resource "uplapse_monitor" "domain_expiry" {
  count = var.checks.domain_expiry ? 1 : 0

  name                    = "${local.prefix}: domain registration"
  type                    = "DOMAIN_EXPIRY"
  url                     = local.domain
  min_domain_days_left    = var.domain_min_days
  interval                = 86400
  tags                    = local.tags
  alert_user_ids          = var.alert_user_ids
  alert_contact_group_ids = var.alert_contact_group_ids
  paused                  = var.paused
}

# Who may send email as the domain (SPF, DMARC), plus the optional MTA-STS requirement and blacklist watch.
resource "uplapse_monitor" "email_auth" {
  count = var.checks.email_auth ? 1 : 0

  name                    = "${local.prefix}: email authentication"
  type                    = "MAIL_AUTH"
  url                     = local.domain
  required_mta_sts_mode   = var.email.required_mta_sts_mode
  check_blacklists        = var.email.check_blacklists
  interval                = 3600
  tags                    = local.tags
  alert_user_ids          = var.alert_user_ids
  alert_contact_group_ids = var.alert_contact_group_ids
  paused                  = var.paused
}

resource "uplapse_monitor" "mail_server" {
  for_each = var.mail_servers

  name                    = "${local.prefix}: mail ${each.key}"
  type                    = "MAIL_SERVER"
  url                     = each.value.host
  mail_protocol           = each.value.protocol
  port                    = each.value.port
  locations               = var.locations
  tags                    = local.tags
  alert_user_ids          = var.alert_user_ids
  alert_contact_group_ids = var.alert_contact_group_ids
  paused                  = var.paused
}

resource "uplapse_monitor" "heartbeat" {
  for_each = var.heartbeats

  name                    = "${local.prefix}: job ${each.key}"
  type                    = "HEARTBEAT"
  interval                = each.value.interval
  heartbeat_grace_seconds = each.value.grace_seconds
  tags                    = local.tags
  alert_user_ids          = var.alert_user_ids
  alert_contact_group_ids = var.alert_contact_group_ids
  paused                  = var.paused
}
