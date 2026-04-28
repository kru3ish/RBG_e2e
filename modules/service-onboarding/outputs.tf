output "repo_url" {
  value       = github_repository.service.html_url
  description = "URL of the created GitHub repository"
}

output "repo_full_name" {
  value       = "${var.repo_org}/${github_repository.service.name}"
  description = "Full name of the GitHub repo (org/name)"
}

output "service_identifier" {
  value       = harness_platform_service.service.identifier
  description = "Identifier of the created Harness service"
}

output "workspace_id" {
  value       = harness_platform_workspace.service_triggers.identifier
  description = "Identifier of the service-triggers IACM workspace"
}

output "watcher_trigger_id" {
  value       = harness_platform_triggers.watcher.identifier
  description = "Identifier of the watcher trigger for auto-reconciliation"
}
