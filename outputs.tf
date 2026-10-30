output "monitor_ids" {
  description = "Ids of the monitors created, by check: uptime, certificate, domain_expiry, email_auth, mail_<name>, job_<name>."
  value = merge(
    { for k, r in {
      uptime        = one(uplapse_monitor.uptime[*].id)
      certificate   = one(uplapse_monitor.certificate[*].id)
      domain_expiry = one(uplapse_monitor.domain_expiry[*].id)
      email_auth    = one(uplapse_monitor.email_auth[*].id)
    } : k => r if r != null },
    { for k, r in uplapse_monitor.mail_server : "mail_${k}" => r.id },
    { for k, r in uplapse_monitor.heartbeat : "job_${k}" => r.id },
  )
}

output "heartbeat_urls" {
  description = "Ping address of each heartbeat, by name. Call it when the job finishes; anyone with it can report, so keep it secret."
  value       = { for k, r in uplapse_monitor.heartbeat : k => r.heartbeat_url }
  sensitive   = true
}
