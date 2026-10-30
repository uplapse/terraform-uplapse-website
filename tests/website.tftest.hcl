# Unit tests with a mocked provider: what the module creates for a given input. No API is called.
#   terraform init && terraform test

mock_provider "uplapse" {
  mock_resource "uplapse_monitor" {
    defaults = {
      id            = "1"
      heartbeat_url = "https://api.example/v1/heartbeat/abc"
    }
  }
}

variables {
  domain = "Example.com"
}

run "defaults_create_the_four_standard_checks" {
  command = plan

  assert {
    condition     = length(uplapse_monitor.uptime) == 1 && length(uplapse_monitor.certificate) == 1 && length(uplapse_monitor.domain_expiry) == 1 && length(uplapse_monitor.email_auth) == 1
    error_message = "expected uptime, certificate, domain registration and email authentication monitors"
  }
  assert {
    condition     = uplapse_monitor.uptime[0].type == "HTTPS" && uplapse_monitor.uptime[0].url == "https://example.com"
    error_message = "uptime should be an HTTPS check of https://<domain>, lower-cased"
  }
  assert {
    condition     = uplapse_monitor.uptime[0].name == "example.com: website" && uplapse_monitor.email_auth[0].name == "example.com: email authentication"
    error_message = "monitor names should be prefixed with the domain"
  }
  assert {
    condition     = uplapse_monitor.certificate[0].url == "example.com" && uplapse_monitor.certificate[0].min_tls_days_left == 14 && uplapse_monitor.certificate[0].interval == 86400
    error_message = "certificate check should watch the domain daily with 14 days' warning"
  }
  assert {
    condition     = uplapse_monitor.domain_expiry[0].min_domain_days_left == 30
    error_message = "domain registration should warn 30 days ahead"
  }
  assert {
    condition     = uplapse_monitor.email_auth[0].type == "MAIL_AUTH" && uplapse_monitor.email_auth[0].check_blacklists == false && uplapse_monitor.email_auth[0].required_mta_sts_mode == null
    error_message = "email authentication should not require MTA-STS or watch blacklists unless asked"
  }
  assert {
    condition     = contains(uplapse_monitor.uptime[0].tags, "example.com")
    error_message = "every monitor should be tagged with the domain"
  }
  assert {
    condition     = length(uplapse_monitor.mail_server) == 0 && length(uplapse_monitor.heartbeat) == 0
    error_message = "no mail server or heartbeat monitors unless listed"
  }
}

run "keyword_makes_a_keyword_check" {
  command = plan

  variables {
    keyword = "Welcome"
    url     = "https://www.example.com/shop"
  }

  assert {
    condition     = uplapse_monitor.uptime[0].type == "KEYWORD" && uplapse_monitor.uptime[0].keyword == "Welcome" && uplapse_monitor.uptime[0].url == "https://www.example.com/shop"
    error_message = "a keyword should turn the uptime check into a KEYWORD check of the given url"
  }
}

run "checks_can_be_turned_off" {
  command = plan

  variables {
    checks = { uptime = false, email_auth = false }
  }

  assert {
    condition     = length(uplapse_monitor.uptime) == 0 && length(uplapse_monitor.email_auth) == 0
    error_message = "turned-off checks should not be created"
  }
  assert {
    condition     = length(uplapse_monitor.certificate) == 1 && length(uplapse_monitor.domain_expiry) == 1
    error_message = "checks left out of the object keep their default (on)"
  }
}

run "mail_servers_heartbeats_and_options" {
  variables {
    name_prefix = "Acme"
    email       = { required_mta_sts_mode = "enforce", check_blacklists = true }
    mail_servers = {
      mailbox = { host = "imap.example.com", protocol = "IMAPS" }
      relay   = { host = "smtp.example.com", protocol = "SUBMISSION", port = 2525 }
    }
    heartbeats = {
      backup = { interval = 86400, grace_seconds = 1800 }
    }
    locations      = [2643743]
    alert_user_ids = [4]
    paused         = true
  }

  assert {
    condition     = uplapse_monitor.mail_server["mailbox"].name == "Acme: mail mailbox" && uplapse_monitor.mail_server["mailbox"].mail_protocol == "IMAPS" && uplapse_monitor.mail_server["mailbox"].url == "imap.example.com"
    error_message = "each mail server should become a MAIL_SERVER monitor"
  }
  assert {
    condition     = uplapse_monitor.mail_server["relay"].port == 2525
    error_message = "a given mail port should be passed on"
  }
  assert {
    condition     = uplapse_monitor.heartbeat["backup"].type == "HEARTBEAT" && uplapse_monitor.heartbeat["backup"].interval == 86400 && uplapse_monitor.heartbeat["backup"].heartbeat_grace_seconds == 1800
    error_message = "each heartbeat should become a HEARTBEAT monitor"
  }
  assert {
    condition     = uplapse_monitor.email_auth[0].required_mta_sts_mode == "enforce" && uplapse_monitor.email_auth[0].check_blacklists
    error_message = "email options should reach the MAIL_AUTH monitor"
  }
  assert {
    condition     = alltrue([for m in concat(uplapse_monitor.uptime, values(uplapse_monitor.mail_server), values(uplapse_monitor.heartbeat)) : m.paused && contains(m.alert_user_ids, 4)])
    error_message = "paused and alert recipients should apply to every monitor"
  }
  assert {
    condition     = contains(uplapse_monitor.uptime[0].locations, 2643743) && uplapse_monitor.certificate[0].locations == null
    error_message = "locations apply to the uptime and mail server checks only"
  }
  assert {
    condition     = toset(keys(output.monitor_ids)) == toset(["uptime", "certificate", "domain_expiry", "email_auth", "mail_mailbox", "mail_relay", "job_backup"])
    error_message = "monitor_ids should list every monitor by check"
  }
  assert {
    condition     = nonsensitive(output.heartbeat_urls["backup"]) == "https://api.example/v1/heartbeat/abc"
    error_message = "heartbeat_urls should give each job's ping address"
  }
}

run "rejects_a_url_as_domain" {
  command = plan
  variables {
    domain = "https://example.com"
  }
  expect_failures = [var.domain]
}

run "rejects_port_25" {
  command = plan
  variables {
    mail_servers = { mx = { host = "mx.example.com", protocol = "SUBMISSION", port = 25 } }
  }
  expect_failures = [var.mail_servers]
}

run "rejects_an_unknown_mail_protocol" {
  command = plan
  variables {
    mail_servers = { mx = { host = "mx.example.com", protocol = "SMTP" } }
  }
  expect_failures = [var.mail_servers]
}

run "rejects_an_unknown_mta_sts_mode" {
  command = plan
  variables {
    email = { required_mta_sts_mode = "strict" }
  }
  expect_failures = [var.email]
}

run "rejects_a_non_http_url" {
  command = plan
  variables {
    url = "ftp://example.com"
  }
  expect_failures = [var.url]
}
