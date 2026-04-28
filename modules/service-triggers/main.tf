# Input sets — one per trigger entry
resource "harness_platform_input_set" "trigger_inputs" {
  for_each = local.trigger_map

  identifier  = "input_${replace(local.repo_name, "-", "_")}_${each.key}"
  name        = "input_${replace(local.repo_name, "-", "_")}_${each.key}"
  org_id      = var.org_id
  project_id  = var.project_id
  pipeline_id = var.pipeline_identifier
  yaml        = <<-EOT
    inputSet:
      identifier: "input_${replace(local.repo_name, "-", "_")}_${each.key}"
      name: "input_${replace(local.repo_name, "-", "_")}_${each.key}"
      tags:
        managed_by: "hsf"
        service_name: "${local.repo_name}"
      orgIdentifier: "${var.org_id}"
      projectIdentifier: "${var.project_id}"
      pipeline:
        identifier: "${var.pipeline_identifier}"
        properties:
          ci:
            codebase:
              connectorRef: "${var.github_connector_ref}"
              repoName: "${local.repo_name}"
              build:
                type: branch
                spec:
                  branch: "${var.repo_branch}"
        variables:
          - name: image_name
            type: String
            value: "${each.value.image_name}"
          - name: path_filter
            type: String
            value: "${each.value.path}"
  EOT
}

# Push/main triggers — fire on merge to main
resource "harness_platform_triggers" "push_trigger" {
  for_each = {
    for k, v in local.trigger_map : k => v
    if contains(v.events, "main")
  }

  identifier = "push_${replace(local.repo_name, "-", "_")}_${each.key}"
  name       = "push_${replace(local.repo_name, "-", "_")}_${each.key}"
  org_id     = var.org_id
  project_id = var.project_id
  target_id  = var.pipeline_identifier
  yaml       = <<-EOT
    trigger:
      name: "push_${replace(local.repo_name, "-", "_")}_${each.key}"
      identifier: "push_${replace(local.repo_name, "-", "_")}_${each.key}"
      enabled: true
      description: "Push trigger for ${var.repo_full_name} path=${each.value.path}"
      tags:
        managed_by: "hsf"
        created_via: "service_triggers_module"
        service_name: "${local.repo_name}"
      orgIdentifier: "${var.org_id}"
      projectIdentifier: "${var.project_id}"
      pipelineIdentifier: "${var.pipeline_identifier}"
      source:
        type: Webhook
        spec:
          type: Github
          spec:
            type: Push
            spec:
              connectorRef: "${var.github_connector_ref}"
              autoAbortPreviousExecutions: false
              payloadConditions:
                - key: targetBranch
                  operator: Equals
                  value: "${var.repo_branch}"
              headerConditions: []
              repoName: "${local.repo_name}"
              actions: []
      inputSetRefs:
        - "input_${replace(local.repo_name, "-", "_")}_${each.key}"
  EOT
}

# PR triggers — fire on pull requests
resource "harness_platform_triggers" "pr_trigger" {
  for_each = {
    for k, v in local.trigger_map : k => v
    if contains(v.events, "pr")
  }

  identifier = "pr_${replace(local.repo_name, "-", "_")}_${each.key}"
  name       = "pr_${replace(local.repo_name, "-", "_")}_${each.key}"
  org_id     = var.org_id
  project_id = var.project_id
  target_id  = var.pipeline_identifier
  yaml       = <<-EOT
    trigger:
      name: "pr_${replace(local.repo_name, "-", "_")}_${each.key}"
      identifier: "pr_${replace(local.repo_name, "-", "_")}_${each.key}"
      enabled: true
      description: "PR trigger for ${var.repo_full_name} path=${each.value.path}"
      tags:
        managed_by: "hsf"
        created_via: "service_triggers_module"
        service_name: "${local.repo_name}"
      orgIdentifier: "${var.org_id}"
      projectIdentifier: "${var.project_id}"
      pipelineIdentifier: "${var.pipeline_identifier}"
      source:
        type: Webhook
        spec:
          type: Github
          spec:
            type: PullRequest
            spec:
              connectorRef: "${var.github_connector_ref}"
              autoAbortPreviousExecutions: true
              payloadConditions: []
              headerConditions: []
              repoName: "${local.repo_name}"
              actions:
                - Open
                - Reopen
                - Synchronize
      inputSetRefs:
        - "input_${replace(local.repo_name, "-", "_")}_${each.key}"
  EOT
}
