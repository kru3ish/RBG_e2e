output "watcher_workspace_id" {
  description = "Identifier of the created watcher workspace (same as trigger ID for tracking)"
  value       = local.watcher_id
}

output "webhook_url" {
  description = "Harness webhook URL registered with GitHub"
  value       = "https://app.harness.io/gateway/ng/api/webhook?accountIdentifier=${var.harness_account_id}"
}

output "webhook_trigger_identifier" {
  description = "Identifier of the Harness trigger in the target workspace's project"
  value       = harness_platform_triggers.watcher.identifier
}
