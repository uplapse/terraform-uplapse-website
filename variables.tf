variable "domain" {
  description = "The domain to watch, e.g. example.com. Used for the certificate, domain registration and email checks, and for monitor names."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", lower(var.domain)))
    error_message = "domain must be a host name such as example.com, without a scheme or path."
  }
}

variable "url" {
  description = "Address of the uptime check. Defaults to https://<domain>."
  type        = string
  default     = null

  validation {
    condition     = var.url == null || can(regex("^https?://", var.url))
    error_message = "url must start with http:// or https://."
  }
}

variable "name_prefix" {
  description = "Prefix of every monitor name. Defaults to the domain, giving names like \"example.com: website\". Monitor names must be unique in the organisation."
  type        = string
  default     = null
}

variable "checks" {
  description = "Which of the standard checks to create."
  type = object({
    uptime        = optional(bool, true)
    certificate   = optional(bool, true)
    domain_expiry = optional(bool, true)
    email_auth    = optional(bool, true)
  })
  default = {}
}

variable "keyword" {
  description = "Text the page must contain. When set, the uptime check is a KEYWORD check instead of a plain HTTPS one."
  type        = string
  default     = null
}

variable "expected_status" {
  description = "HTTP status the uptime check must get (default: any successful status)."
  type        = number
  default     = null
}

variable "interval" {
  description = "Seconds between uptime checks. Defaults to the plan's shortest interval."
  type        = number
  default     = null
}

variable "locations" {
  description = "City ids to run the uptime and mail server checks from (see the uplapse_locations data source). Left out, each check runs once from whichever checking location is available."
  type        = set(number)
  default     = null
}

variable "certificate_min_days" {
  description = "Fail the certificate check once fewer days than this remain."
  type        = number
  default     = 14
}

variable "domain_min_days" {
  description = "Fail the domain registration check once fewer days than this remain."
  type        = number
  default     = 30
}

variable "email" {
  description = "Email authentication options: require MTA-STS (testing or enforce) and watch the mail servers' addresses on IP blacklists."
  type = object({
    required_mta_sts_mode = optional(string)
    check_blacklists      = optional(bool, false)
  })
  default = {}

  validation {
    condition     = var.email.required_mta_sts_mode == null || contains(["testing", "enforce"], coalesce(var.email.required_mta_sts_mode, "-"))
    error_message = "email.required_mta_sts_mode must be testing or enforce."
  }
}

variable "mail_servers" {
  description = "Mail servers to check, keyed by a short name: host, protocol (SUBMISSION, SMTPS, IMAP, IMAPS, POP3, POP3S) and an optional port. Port 25 cannot be monitored."
  type = map(object({
    host     = string
    protocol = string
    port     = optional(number)
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.mail_servers) : contains(["SUBMISSION", "SMTPS", "IMAP", "IMAPS", "POP3", "POP3S"], s.protocol)])
    error_message = "mail_servers protocol must be one of SUBMISSION, SMTPS, IMAP, IMAPS, POP3, POP3S."
  }
  validation {
    condition     = alltrue([for s in values(var.mail_servers) : s.port != 25])
    error_message = "Port 25 cannot be monitored: the checking locations' cloud providers block it. Use 587 or 465."
  }
}

variable "heartbeats" {
  description = "Scheduled jobs that must report in, keyed by a short name: interval (seconds between runs) and optional grace_seconds. Their ping addresses are in the heartbeat_urls output."
  type = map(object({
    interval      = number
    grace_seconds = optional(number)
  }))
  default = {}
}

variable "tags" {
  description = "Tags on every monitor. The domain is always added."
  type        = set(string)
  default     = []
}

variable "alert_user_ids" {
  description = "Users alerted by every monitor. Left null, recipients chosen in the app are kept."
  type        = set(number)
  default     = null
}

variable "alert_contact_group_ids" {
  description = "Contact groups alerted by every monitor. Left null, groups chosen in the app are kept."
  type        = set(number)
  default     = null
}

variable "paused" {
  description = "Pause every monitor of this domain."
  type        = bool
  default     = false
}
