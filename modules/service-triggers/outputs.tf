output "workspace_id" {
  description = "This workspace's own identifier (for the generic pipeline to point its webhook at)"
  value       = "service_triggers_${replace(local.repo_name, "-", "_")}"
}

output "input_set_ids" {
  description = "Map of input set identifiers keyed by path"
  value = {
    for k, v in harness_platform_input_set.trigger_inputs : k => v.identifier
  }
}

output "push_trigger_ids" {
  description = "Map of push/main trigger identifiers keyed by path"
  value = {
    for k, v in harness_platform_triggers.push_trigger : k => v.identifier
  }
}

output "pr_trigger_ids" {
  description = "Map of PR trigger identifiers keyed by path"
  value = {
    for k, v in harness_platform_triggers.pr_trigger : k => v.identifier
  }
}
