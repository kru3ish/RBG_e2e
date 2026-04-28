# HSF Create-a-Service: Architecture

## Overview

The HSF (Harness Solutions Factory) "Create a Service" flow is a self-service developer onboarding system. A developer fills a two-field IDP form, and the system provisions a GitHub repository, a Harness service, CI triggers, and auto-reconciliation wiring -- all without touching the Harness UI.

This is the Session 2 deliverable. It builds on Session 1's generic wiring primitive (`trigger_workspace_on_git_file_change`), which handles the "watch a file and apply a workspace" pattern.

## End-to-End Flow

```
+-------------------+
|   IDP Form        |
|  "Create a        |
|   Service"        |
|                   |
|  service_name: x  |
|  target_project: y|
+--------+----------+
         |
         v
+--------+---------------------------------------------+
| HSF Pipeline: create_service                          |
|                                                       |
|  Stage 1: Scaffold Repo                               |
|    - Create GitHub repo (Kru3ish/<service_name>)      |
|    - Seed .harness/triggers.yaml (default template)   |
|    - Seed Dockerfile                                  |
|                                                       |
|  Stage 2: Create Harness Service                      |
|    - POST to Harness Services API                     |
|    - Creates service in target_project                |
|                                                       |
|  Stage 3: Create Workspace A                          |
|    - IACM workspace: service_triggers_<name>          |
|    - Points at modules/service-triggers/              |
|    - Triggers Provision_Workspace to apply             |
|    - Polls until apply completes                      |
|                                                       |
|  Stage 4: Wire Auto-Apply                             |
|    - Calls Session 1 pipeline:                        |
|      trigger_workspace_on_git_file_change             |
|    - Creates Workspace B (the watcher)                |
|    - Registers webhook on the new repo                |
|    - Polls until wiring completes                     |
+-------------------------------------------------------+
         |
         v
+-------------------------------------------------------+
| Result: Service fully wired                           |
|                                                       |
|  GitHub:                                              |
|    - Repo: Kru3ish/<service_name>                     |
|    - File: .harness/triggers.yaml                     |
|    - Webhook: fires on push to main                   |
|                                                       |
|  Harness:                                             |
|    - Service in target_project                        |
|    - Input sets (one per triggers.yaml entry)         |
|    - PR triggers (one per entry with "pr" event)      |
|    - Push triggers (one per entry with "main" event)  |
|    - Workspace A: service_triggers_<name>             |
|    - Workspace B: watcher_<workspace_a>_<repo>        |
+-------------------------------------------------------+
```

## The Two-Workspace Pattern

Every service creates exactly two IACM workspaces:

### Workspace A: Service Triggers

- **Identifier:** `service_triggers_<service_name>` (hyphens replaced with underscores)
- **Terraform module:** `modules/service-triggers/`
- **Purpose:** Reads `.harness/triggers.yaml` from the service repo and creates corresponding Harness resources (input sets, PR triggers, push triggers).
- **Lives in:** HSF project (`Harness_Platform_Management / Solutions_Factory`)
- **Applies against:** The target project where the developer's service lives.

On each apply, Workspace A:
1. Fetches `.harness/triggers.yaml` from GitHub via raw content URL.
2. Parses the YAML with `yamldecode()`.
3. Iterates over each trigger entry using `for_each`.
4. Creates/updates an input set, a push trigger (if `main` is in events), and a PR trigger (if `pr` is in events) for each entry.

### Workspace B: Watcher

- **Identifier:** `watcher_<workspace_a_id>_<repo_name>`
- **Created by:** Session 1's `trigger_workspace_on_git_file_change` pipeline
- **Purpose:** Watches `.harness/triggers.yaml` for changes and auto-applies Workspace A when the file is modified on the main branch.
- **Mechanism:** A webhook trigger on the `Provision_Workspace` pipeline, filtered to fire only when `.harness/triggers.yaml` changes.

### How They Connect

```
Developer edits .harness/triggers.yaml
         |
         v
GitHub push event (main branch)
         |
         v
Workspace B's webhook trigger fires
         |
         v
Provision_Workspace pipeline runs
with workspace = Workspace A
         |
         v
Workspace A re-reads triggers.yaml
         |
         v
New triggers/input sets materialize
in the developer's Harness project
```

## Day-2 Auto-Reconciliation

After the initial `create_service` pipeline run, the system is fully self-managing:

1. Developer clones their repo and edits `.harness/triggers.yaml` (e.g., adding a monorepo path entry).
2. Developer opens a PR and merges to `main`.
3. GitHub fires a push webhook to Harness.
4. Workspace B's trigger matches (file path `.harness/triggers.yaml` changed on `main`).
5. The `Provision_Workspace` pipeline runs with Workspace A's identifier.
6. Workspace A fetches the updated `triggers.yaml`, diffs its state, and creates/updates/deletes triggers accordingly.
7. New triggers appear in the developer's Harness project within about 30 seconds of merge.

The developer never visits the Harness UI. Merging the file makes it happen.

## Component Inventory

### Pipelines

| Pipeline | Identifier | Owner | Purpose |
|----------|-----------|-------|---------|
| Create a Service | `create_service` | Session 2 | Full onboarding flow (4 stages) |
| Trigger Workspace on Git File Change | `trigger_workspace_on_git_file_change` | Session 1 | Generic wiring primitive |
| Provision Workspace | `Provision_Workspace` | HSF (pre-existing) | Runs IACM init/plan/approve/apply |

All pipelines live in `Harness_Platform_Management / Solutions_Factory`.

### Terraform Modules

| Module | Path | Purpose |
|--------|------|---------|
| service-triggers | `modules/service-triggers/` | Workspace A's Terraform -- reads triggers.yaml, creates input sets + triggers |
| watcher-workspace | `modules/watcher-workspace/` | Workspace B's Terraform -- creates webhook trigger on Provision_Workspace |

### IDP Workflow

| File | Purpose |
|------|---------|
| `idp/workflows/create-service/workflow.yaml` | Backstage scaffolder template with two-field form |

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/discover.sh` | Discovers Harness account config, writes `discovery.json` |
| `bootstrap/create-pipeline.sh` | Deploys Session 1's pipeline to HSF |
| `bootstrap/deploy.sh` | Deploys Session 2's pipeline to HSF |
| `demo/setup.sh` | Creates demo test resources |
| `demo/teardown.sh` | Cleans up demo resources |

### Key Files

| File | Purpose |
|------|---------|
| `discovery.json` | Discovered account configuration |
| `scaffolding/triggers.yaml.tmpl` | Default triggers.yaml template seeded into new repos |
| `docs/CONTRACT.md` | Session 1/Session 2 interface contract |
| `docs/MONOREPO-TRIGGERS-YAML-SCHEMA.md` | Schema reference for triggers.yaml |

## Naming Conventions

- **Pipeline identifiers:** snake_case (`create_service`, `trigger_workspace_on_git_file_change`)
- **Workspace A:** `service_triggers_<service_name>` (hyphens become underscores)
- **Workspace B:** `watcher_<workspace_a_id>_<repo_name>` (hyphens become underscores)
- **Triggers:** `push_<repo>_<path_key>`, `pr_<repo>_<path_key>`
- **Input sets:** `input_<repo>_<path_key>`
- **Resource tags:** `managed_by=hsf`, `created_via=create_service_workflow`, `service_name=<name>`

## Infrastructure

- **Build infrastructure:** Harness Cloud (Linux/Amd64) -- no Kubernetes cluster required.
- **IACM provisioner:** OpenTofu 1.9.0
- **GitHub connectors:** `account.github` (private repos, Kru3ish org), `account.github_public` (public repos)
- **Harness account:** `Qjf4MwsLRUes1w_efM3eIw`
- **HSF location:** Org `Harness_Platform_Management`, Project `Solutions_Factory`
