# Session 2 Contract: trigger_workspace_on_git_file_change

This document specifies the stable interface for the generic HSF wiring pipeline.
Session 2 depends on this contract. Do not change without coordinating.

## Pipeline Identifier

```
trigger_workspace_on_git_file_change
```

Located in:
- **Org:** `Harness_Platform_Management`
- **Project:** `Solutions_Factory`

## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `target_workspace_id` | String | Yes | — | Identifier of the IACM workspace to apply on file change |
| `repo_org` | String | Yes | — | GitHub organization group (RBG, IAA, kru3ish, etc.) |
| `repo_name` | String | Yes | — | Repository name within the org |
| `file_paths` | String | Yes | `.harness/triggers.yaml` | Comma-separated list of file paths to watch |
| `branch` | String | No | `main` | Git branch to watch |

## Outputs

Access via: `<+pipeline.stages.Create_Watcher_Workspace.spec.execution.steps.create_trigger.output.outputVariables.VARIABLE_NAME>`

| Name | Description |
|------|-------------|
| `watcher_workspace_id` | Identifier of the created watcher (format: `watcher_<target>_<repo>`) |
| `webhook_url` | Harness webhook URL registered with GitHub |
| `webhook_trigger_identifier` | Identifier of the Harness trigger on the Provision_Workspace_Auto pipeline |

## How to Call This Pipeline from Session 2

### As a child pipeline stage

```yaml
- stage:
    name: Wire Git Trigger
    identifier: Wire_Git_Trigger
    type: Pipeline
    spec:
      org: Harness_Platform_Management
      project: Solutions_Factory
      pipeline: trigger_workspace_on_git_file_change
      inputs:
        target_workspace_id: <+pipeline.variables.workspace_id>
        repo_org: <+pipeline.variables.repo_org>
        repo_name: <+pipeline.variables.repo_name>
        file_paths: ".harness/triggers.yaml"
        branch: "main"
```

### Reading outputs after the child pipeline completes

```yaml
# Watcher workspace ID
<+pipeline.stages.Wire_Git_Trigger.pipeline.stages.Create_Watcher_Workspace.spec.execution.steps.create_trigger.output.outputVariables.watcher_workspace_id>

# Webhook URL
<+pipeline.stages.Wire_Git_Trigger.pipeline.stages.Create_Watcher_Workspace.spec.execution.steps.create_trigger.output.outputVariables.webhook_url>

# Trigger identifier
<+pipeline.stages.Wire_Git_Trigger.pipeline.stages.Create_Watcher_Workspace.spec.execution.steps.create_trigger.output.outputVariables.webhook_trigger_identifier>
```

## Behavior

1. Pipeline creates a webhook trigger on the `Provision_Workspace_Auto` pipeline
2. The trigger fires on Push events to `<branch>` when any file in `<file_paths>` changes
3. When triggered, the `Provision_Workspace_Auto` pipeline runs with `workspace: <target_workspace_id>`
4. This causes an IACM init → plan → approve → apply on the target workspace
5. The trigger is idempotent — re-running with the same inputs updates the existing trigger

## Naming Convention

- Trigger ID: `trigger_<target_workspace_id>_<repo_name_underscored>`
- Watcher ID: `watcher_<target_workspace_id>_<repo_name_underscored>`

## Dependencies

- `Provision_Workspace_Auto` pipeline must exist in the same project
- GitHub connector (`account.github` or `account.github_public`) must have webhook permissions
- Secret `account.harness_platform_api_key` must be accessible
