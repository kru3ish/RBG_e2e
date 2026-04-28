locals {
  connector_ref = lookup(var.connector_map, var.repo_org, var.default_connector)
  watcher_id    = "watcher_${var.target_workspace_id}_${replace(var.repo_name, "-", "_")}"
  trigger_id    = "trigger_${var.target_workspace_id}_${replace(var.repo_name, "-", "_")}"

  # Build changedFiles regex from comma-separated file_paths
  file_path_list = [for p in split(",", var.file_paths) : trimspace(p)]
  file_regex     = join("|", local.file_path_list)
}

resource "harness_platform_triggers" "watcher" {
  identifier = local.trigger_id
  name       = local.trigger_id
  org_id     = var.org_id
  project_id = var.project_id
  target_id  = var.target_pipeline_id
  yaml       = <<-EOT
    trigger:
      name: "${local.trigger_id}"
      identifier: "${local.trigger_id}"
      enabled: true
      description: "Auto-apply ${var.target_workspace_id} when ${join(", ", local.file_path_list)} changes in ${var.repo_org}/${var.repo_name}"
      tags:
        hsf_managed: "true"
        watcher_for: "${var.target_workspace_id}"
      orgIdentifier: "${var.org_id}"
      projectIdentifier: "${var.project_id}"
      pipelineIdentifier: "${var.target_pipeline_id}"
      source:
        type: Webhook
        spec:
          type: Github
          spec:
            type: Push
            spec:
              connectorRef: "${local.connector_ref}"
              autoAbortPreviousExecutions: false
              payloadConditions:
                - key: targetBranch
                  operator: Equals
                  value: "${var.branch}"
                - key: changedFiles
                  operator: Regex
                  value: "${local.file_regex}"
              headerConditions: []
              repoName: "${var.repo_name}"
              actions: []
      inputYaml: |
        pipeline:
          identifier: ${var.target_pipeline_id}
          stages:
            - stage:
                identifier: Provision
                type: IACM
                spec:
                  workspace: ${var.target_workspace_id}
  EOT
}
