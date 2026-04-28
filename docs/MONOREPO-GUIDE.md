# Monorepo Guide: Managing Services via triggers.yaml

This guide explains how to add, modify, and remove services in a monorepo by editing the `.harness/triggers.yaml` file. No Harness UI interaction is required.

## How It Works

Every repo created by the HSF "Create a Service" flow contains a `.harness/triggers.yaml` file. This file is the single source of truth for what CI triggers exist in Harness for that repo.

When you edit `triggers.yaml` and merge to `main`:

1. A GitHub webhook fires (registered automatically during service creation).
2. Workspace B detects the file change and triggers the `Provision_Workspace` pipeline.
3. Workspace A re-reads `triggers.yaml`, diffs with current state, and creates/updates/deletes triggers.
4. New triggers appear in Harness within about 30 seconds.

You never touch the Harness UI. The file is the interface.

## The triggers.yaml Schema

```yaml
triggers:
  - path: "<glob pattern>"      # Required. Path filter for the trigger.
    events: [pr, main]          # Required. Which events fire the trigger.
    image_name: "<string>"      # Required. Container image name for this entry.
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | Yes | Glob pattern for file path filtering. `"*"` matches all paths. `"apps/api/**"` matches everything under `apps/api/`. |
| `events` | list | Yes | Events to trigger on. Valid values: `pr` (pull request opened/reopened/synced), `main` (push to main branch). |
| `image_name` | string | Yes | Container image name associated with this trigger entry. Passed as a pipeline variable. |

### Path Pattern Rules

- `"*"` -- matches all file changes in the repo (single-service repos).
- `"apps/api/**"` -- matches any file change under `apps/api/`.
- `"libs/common/**"` -- matches any file change under `libs/common/`.
- Patterns follow standard glob syntax.

### Event Values

- `pr` -- creates a PR trigger that fires on pull request Open, Reopen, and Synchronize actions.
- `main` -- creates a push trigger that fires on merge to the main branch.
- You can use one or both: `[pr]`, `[main]`, or `[pr, main]`.

## Examples

### Single-Service Repo (Default)

This is what gets created automatically when you create a new service. One trigger entry covering all file paths.

```yaml
triggers:
  - path: "*"
    events: [pr, main]
    image_name: my-service
```

**Creates:**
- 1 input set: `input_my_service_all`
- 1 push trigger: `push_my_service_all`
- 1 PR trigger: `pr_my_service_all`

### Monorepo with Multiple Services

A repo containing an API backend and a web frontend, each with their own build pipeline triggers.

```yaml
triggers:
  - path: "apps/api/**"
    events: [pr, main]
    image_name: api-service

  - path: "apps/web/**"
    events: [pr, main]
    image_name: web-frontend

  - path: "libs/common/**"
    events: [main]
    image_name: common-lib
```

**Creates:**
- 3 input sets (one per entry)
- 2 push triggers (api and web have `main`; common-lib has `main`)
- 2 PR triggers (only api and web have `pr`)

Wait -- correction: 3 push triggers (all three have `main`), and 2 PR triggers (only api and web have `pr`).

### PR-Only Triggers

Useful for test suites or linting that should only run on PRs, never on merge.

```yaml
triggers:
  - path: "tests/**"
    events: [pr]
    image_name: test-runner
```

**Creates:**
- 1 input set
- 1 PR trigger
- No push trigger

### Push-Only Triggers

Useful for deployment pipelines that should only fire on merge, not on PRs.

```yaml
triggers:
  - path: "deploy/**"
    events: [main]
    image_name: deploy-runner
```

**Creates:**
- 1 input set
- 1 push trigger
- No PR trigger

## Step-by-Step: Adding a Service to a Monorepo

### 1. Clone the repo

```bash
git clone https://github.com/Kru3ish/<repo-name>.git
cd <repo-name>
```

### 2. Edit triggers.yaml

Open `.harness/triggers.yaml` and add a new entry:

```yaml
triggers:
  - path: "*"
    events: [pr, main]
    image_name: my-service

  # New entry for the experimental service
  - path: "apps/experimental/**"
    events: [pr]
    image_name: experimental-service
```

### 3. Commit and push

```bash
git checkout -b add-experimental-triggers
git add .harness/triggers.yaml
git commit -m "Add triggers for apps/experimental"
git push origin add-experimental-triggers
```

### 4. Open a PR and merge

Open a pull request on GitHub. Review the diff to confirm the YAML is valid. Merge to `main`.

### 5. Verify the triggers appeared

Wait about 30 seconds after merge. Then check in the Harness UI:

1. Navigate to your target project > Pipelines > select the CI pipeline.
2. Go to the **Triggers** tab.
3. Confirm a new trigger `pr_<repo>_apps_experimental____` exists and is enabled.
4. Go to the **Input Sets** tab.
5. Confirm a new input set `input_<repo>_apps_experimental____` exists.

Alternatively, check via the IACM workspace:

1. Navigate to `Harness_Platform_Management / Solutions_Factory` > IACM > Workspaces.
2. Open `service_triggers_<repo_name>`.
3. Confirm a new execution completed successfully after your merge.

## What Happens Under the Hood

When you merge your `triggers.yaml` change, the following sequence occurs:

```
1. GitHub sends a push webhook to Harness.

2. Harness evaluates all triggers on the Provision_Workspace pipeline.
   Workspace B's trigger matches because:
   - Branch is "main"
   - Changed file matches ".harness/triggers.yaml"

3. Provision_Workspace runs with workspace = Workspace A.
   - IACM init: downloads modules/service-triggers/ from the repo
   - IACM plan: fetches triggers.yaml via HTTP, diffs against Terraform state
   - IACM approve: auto-approved (or manual, depending on workspace config)
   - IACM apply: creates/updates/deletes triggers and input sets

4. Terraform's for_each over the triggers list handles the diff:
   - New entries: creates new input set + trigger(s)
   - Modified entries: updates existing resources
   - Removed entries: destroys orphaned resources
```

## Removing a Service from a Monorepo

To remove triggers for a service, delete the entry from `triggers.yaml` and merge. Terraform will destroy the corresponding input set and triggers on the next apply.

Before:

```yaml
triggers:
  - path: "apps/api/**"
    events: [pr, main]
    image_name: api-service

  - path: "apps/legacy/**"
    events: [pr, main]
    image_name: legacy-service
```

After (removing legacy):

```yaml
triggers:
  - path: "apps/api/**"
    events: [pr, main]
    image_name: api-service
```

Merge this change. Workspace A will destroy `input_<repo>_apps_legacy____`, `push_<repo>_apps_legacy____`, and `pr_<repo>_apps_legacy____`.

## Common Mistakes

- **Invalid YAML syntax.** Use a YAML linter before committing. Missing colons, bad indentation, or unquoted special characters will cause Workspace A's apply to fail.
- **Duplicate path keys.** Each `path` value must be unique within the file. Two entries with `path: "apps/api/**"` will cause a Terraform `for_each` collision.
- **Forgetting quotes around glob patterns.** Always quote paths containing `*`: `"*"`, `"apps/**"`. Unquoted `*` is valid YAML but can cause unexpected parsing in some contexts.
- **Editing the wrong branch.** Only merges to `main` trigger auto-reconciliation. Changes on feature branches have no effect until merged.
