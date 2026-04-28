locals {
  service_id = replace(var.service_name, "-", "_")
}

# =============================================================
# Stage 1 equivalent: Scaffold GitHub Repo
# =============================================================

resource "github_repository" "service" {
  name        = var.service_name
  description = "Service ${var.service_name} — created by HSF Create-a-Service"
  visibility  = "public"
  auto_init   = true
}

resource "github_repository_file" "triggers_yaml" {
  repository          = github_repository.service.name
  branch              = "main"
  file                = ".harness/triggers.yaml"
  content             = <<-EOT
    triggers:
      - path: "*"
        events: [pr, main]
        image_name: ${var.service_name}
  EOT
  commit_message      = "Seed triggers.yaml via HSF Create-a-Service"
  overwrite_on_create = true
}

resource "github_repository_file" "dockerfile" {
  repository          = github_repository.service.name
  branch              = "main"
  file                = "Dockerfile"
  content             = <<-EOT
    FROM alpine:3.19
    LABEL service="${var.service_name}"
    CMD ["echo", "Hello from ${var.service_name}"]
  EOT
  commit_message      = "Add Dockerfile via HSF Create-a-Service"
  overwrite_on_create = true
}

# =============================================================
# Stage 2 equivalent: Create Harness Service
# =============================================================

resource "harness_platform_service" "service" {
  identifier  = local.service_id
  name        = var.service_name
  description = "Service created by HSF Create-a-Service workflow"
  org_id      = var.target_org
  project_id  = var.target_project

  tags = ["managed_by:hsf", "created_via:create_service_workflow"]
}

# =============================================================
# Stage 3 equivalent: Create IACM Workspace for service-triggers
# =============================================================

resource "harness_platform_workspace" "service_triggers" {
  name                 = "Service Triggers: ${var.service_name}"
  identifier           = "service_triggers_${local.service_id}"
  org_id               = var.hsf_org
  project_id           = var.hsf_project
  provisioner_type     = "opentofu"
  provisioner_version  = "1.9.0"
  cost_estimation_enabled = false
  repository              = "kru3ish/RBG_e2e"
  repository_branch       = "main"
  repository_path         = "modules/service-triggers"
  repository_connector    = "account.github_public"
  provider_connector      = ""

  terraform_variable {
    key        = "harness_account_id"
    value      = var.harness_account_id
    value_type = "string"
  }
  terraform_variable {
    key        = "org_id"
    value      = var.target_org
    value_type = "string"
  }
  terraform_variable {
    key        = "project_id"
    value      = var.target_project
    value_type = "string"
  }
  terraform_variable {
    key        = "repo_full_name"
    value      = "${var.repo_org}/${var.service_name}"
    value_type = "string"
  }
  terraform_variable {
    key        = "github_connector_ref"
    value      = var.github_connector_ref
    value_type = "string"
  }
  terraform_variable {
    key        = "pipeline_identifier"
    value      = var.pipeline_template_id
    value_type = "string"
  }
  terraform_variable {
    key        = "github_token"
    value      = ""
    value_type = "string"
  }
  terraform_variable {
    key        = "harness_platform_api_key"
    value      = var.harness_platform_api_key
    value_type = "string"
  }
}

# =============================================================
# Stage 4 equivalent: Wire Auto-Apply (watcher trigger)
# =============================================================

resource "harness_platform_triggers" "watcher" {
  identifier = "trigger_service_triggers_${local.service_id}_${local.service_id}"
  name       = "trigger_service_triggers_${local.service_id}_${local.service_id}"
  org_id     = var.hsf_org
  project_id = var.hsf_project
  target_id  = "Provision_Workspace_Auto"
  yaml       = <<-EOT
    trigger:
      name: "trigger_service_triggers_${local.service_id}_${local.service_id}"
      identifier: "trigger_service_triggers_${local.service_id}_${local.service_id}"
      enabled: true
      description: "Auto-apply service_triggers_${local.service_id} when files change in ${var.repo_org}/${var.service_name}"
      tags:
        hsf_managed: "true"
        watcher_for: "service_triggers_${local.service_id}"
      orgIdentifier: "${var.hsf_org}"
      projectIdentifier: "${var.hsf_project}"
      pipelineIdentifier: "Provision_Workspace_Auto"
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
                  value: "main"
                - key: changedFiles
                  operator: Regex
                  value: ".harness/triggers.yaml"
              headerConditions: []
              repoName: "${var.service_name}"
              actions: []
      inputYaml: |
        pipeline:
          identifier: Provision_Workspace_Auto
          stages:
            - stage:
                identifier: Provision
                type: IACM
                spec:
                  workspace: service_triggers_${local.service_id}
  EOT

  depends_on = [harness_platform_workspace.service_triggers]
}
