# Troubleshooting Guide

This document covers common failures in the HSF "Create a Service" flow and how to resolve them.

## Pipeline Failures by Stage

### Stage 1: Scaffold Repo

#### GitHub token invalid or expired

**Symptom:** Stage 1 fails with `ERROR: Failed to create repo (HTTP 401)`.

**Cause:** The secret `account.githubABC` (referenced as `GITHUB_TOKEN_SECRET`) contains an expired or invalid GitHub personal access token.

**Fix:**
1. Generate a new GitHub PAT with `repo` scope at `https://github.com/settings/tokens`.
2. Update the Harness secret `account.githubABC` with the new token.
3. Re-run the pipeline.

#### Repository already exists in a different org

**Symptom:** Stage 1 fails with `ERROR: Failed to create repo (HTTP 422)` and message about name already being taken.

**Cause:** The repo name is already used under the GitHub user/org. The pipeline creates repos under the authenticated user via `POST /user/repos`, not under an organization.

**Fix:**
- Choose a different service name.
- Or delete the existing repo if it was from a previous failed run: `https://github.com/Kru3ish/<service_name>/settings` > Danger Zone > Delete.
- Or if the repo exists and is valid, the pipeline will skip creation and proceed to seed files. This is normally not an error -- check if the HTTP code check is hitting a different issue.

#### GitHub API rate limit

**Symptom:** Stage 1 fails with HTTP 403 and a message about rate limiting.

**Cause:** Too many GitHub API calls in a short period.

**Fix:** Wait 5-10 minutes and retry. Check rate limit status: `curl -H "Authorization: token <token>" https://api.github.com/rate_limit`.

---

### Stage 2: Create Harness Service

#### Insufficient permissions

**Symptom:** Stage 2 fails with `ERROR: Failed to create service (HTTP 403)`.

**Cause:** The API key (`account.harness_platform_api_key`) does not have permission to create services in the target project.

**Fix:**
1. Verify the API key has the `Service: Create/Edit` permission in the target org/project.
2. Check that `target_org` and `target_project` pipeline variables are correct.
3. If using a service account token, ensure the service account is assigned to the target project.

#### Duplicate service identifier

**Symptom:** Stage 2 fails with HTTP 409 or a message about duplicate identifier.

**Cause:** A service with the same identifier already exists in the target project. The identifier is derived from `service_name` by replacing hyphens with underscores.

**Fix:**
- The pipeline checks for existing services and skips creation if found. If you are seeing this error, the existence check may be returning an unexpected status code.
- Verify the service does not already exist: navigate to the target project > Services in the Harness UI.
- If the service exists from a previous run, this stage should skip. Check the step logs for the exact HTTP response.

#### Target project does not exist

**Symptom:** Stage 2 fails with HTTP 404.

**Cause:** The `target_project` value does not correspond to an existing Harness project, or `target_org` is wrong.

**Fix:**
- Confirm the project exists in the Harness UI under the specified org.
- Check that the `target_org` variable is set correctly (defaults to `Harness_Platform_Management`).

---

### Stage 3: Create Workspace A

#### IACM workspace creation fails

**Symptom:** Stage 3 fails with `ERROR: Failed to create workspace (HTTP 4xx)`.

**Cause:** Common causes include:
- The workspace identifier is too long (max 128 characters).
- The repository path `modules/service-triggers` does not exist in the referenced Git repo.
- The Git connector `account.github` cannot access the `RBG_e2e` repo.

**Fix:**
1. Check that the `Kru3ish/RBG_e2e` repo exists and contains `modules/service-triggers/`.
2. Verify `account.github` connector can access the repo (test connection in Harness UI > Connectors).
3. If the workspace name is too long, use a shorter service name.

#### Provision_Workspace pipeline fails

**Symptom:** Stage 3 logs show `ERROR: Provision_Workspace failed with status: Failed`.

**Cause:** The IACM apply of Workspace A failed. Common reasons:
- `triggers.yaml` cannot be fetched from GitHub (repo is private, token missing, or file does not exist yet).
- Terraform plan errors in `modules/service-triggers/` (invalid variable values, provider issues).
- The target CI pipeline (`pipeline_template_id`) does not exist in the target project.

**Fix:**
1. Check the `Provision_Workspace` execution in the Harness UI for detailed logs.
2. Navigate to IACM > Workspaces > `service_triggers_<name>` > Executions to see the Terraform plan/apply output.
3. Verify the `triggers.yaml` file exists in the new repo: `https://raw.githubusercontent.com/Kru3ish/<service_name>/main/.harness/triggers.yaml`.
4. Verify the CI pipeline identifier exists in the target project.

#### Provision_Workspace times out

**Symptom:** Stage 3 logs show `ERROR: Provision_Workspace timed out`.

**Cause:** The pipeline did not complete within 5 minutes (30 polls at 10-second intervals). This can happen if the IACM workspace requires manual approval.

**Fix:**
1. Check the Provision_Workspace execution status in the Harness UI.
2. If it is waiting for approval, approve it manually.
3. If this is a recurring issue, configure the workspace for auto-approval.

---

### Stage 4: Wire Auto-Apply

#### Session 1 pipeline not deployed

**Symptom:** Stage 4 fails with `ERROR: Failed to trigger Session 1 pipeline (HTTP 404)`.

**Cause:** The `trigger_workspace_on_git_file_change` pipeline does not exist in the HSF project.

**Fix:**
1. Run Session 1's bootstrap: `./bootstrap/create-pipeline.sh`.
2. Verify the pipeline exists: navigate to `Harness_Platform_Management / Solutions_Factory` > Pipelines in the Harness UI.
3. Re-run the `create_service` pipeline (it is safe to re-run; all stages are idempotent).

#### Session 1 pipeline fails

**Symptom:** Stage 4 logs show `ERROR: Session 1 pipeline failed with status: Failed`.

**Cause:** The `trigger_workspace_on_git_file_change` pipeline encountered an error creating the webhook trigger.

**Fix:**
1. Check the execution of `trigger_workspace_on_git_file_change` in the Harness UI for detailed logs.
2. Common issues:
   - The `Provision_Workspace` pipeline does not exist (it is the target of the webhook trigger).
   - The GitHub connector does not have webhook permissions.
   - A trigger with the same identifier already exists but is in a bad state.

#### Session 1 pipeline times out

**Symptom:** Stage 4 logs show `ERROR: Session 1 pipeline timed out`.

**Fix:** Same as Provision_Workspace timeout -- check the execution in the Harness UI and approve any pending stages.

---

## Day-2 Auto-Apply Issues

### Auto-apply does not fire after merging triggers.yaml

**Symptom:** You merged a change to `.harness/triggers.yaml` on `main`, but Workspace A was not re-applied.

**Possible causes and fixes:**

1. **Webhook not registered on GitHub.**
   - Go to `https://github.com/Kru3ish/<repo>/settings/hooks`.
   - Confirm a webhook exists pointing to `https://app.harness.io/gateway/ng/api/webhook?accountIdentifier=Qjf4MwsLRUes1w_efM3eIw`.
   - If missing, re-run Stage 4 of the `create_service` pipeline.

2. **Webhook registered but not delivering.**
   - On GitHub, go to the webhook > Recent Deliveries tab.
   - Check for failed deliveries (non-2xx response).
   - If GitHub shows 401/403, the Harness account webhook endpoint may require re-authentication.

3. **Trigger disabled in Harness.**
   - Navigate to `Harness_Platform_Management / Solutions_Factory` > Pipelines > `Provision_Workspace` > Triggers tab.
   - Find the trigger for your repo (named `trigger_service_triggers_<name>_<repo>`).
   - Confirm it is enabled.

4. **File path does not match the trigger filter.**
   - The trigger watches for `.harness/triggers.yaml` specifically. If you renamed or moved the file, the regex will not match.
   - Check the trigger's `changedFiles` condition in the trigger YAML.

5. **Branch does not match.**
   - The trigger watches the `main` branch. If your default branch is `master` or something else, the trigger will not fire.

6. **Connector cannot receive webhooks.**
   - The GitHub connector (`account.github`) must have webhook permissions enabled.
   - Test by navigating to Connectors > `github` > Test Connection in the Harness UI.

### Auto-apply fires but Workspace A apply fails

**Symptom:** You can see a new execution of `Provision_Workspace` for Workspace A, but it failed.

**Fix:**
1. Open the execution in the Harness UI and check the Terraform plan/apply output.
2. Common causes:
   - **Invalid YAML in triggers.yaml.** Terraform's `yamldecode()` will fail on malformed YAML. Fix the file and re-merge.
   - **Duplicate for_each keys.** Two trigger entries with the same `path` value (after sanitization) cause a collision. Each path must be unique.
   - **GitHub raw content not yet updated.** GitHub's CDN can cache raw content for up to 5 minutes. If the apply reads stale content, it may not see your changes. Wait and re-trigger manually if needed.

---

## triggers.yaml Parse Errors

### YAML syntax error

**Symptom:** Workspace A apply fails with `Error: Error in function call` or `yamldecode: invalid YAML`.

**Common causes:**
- Missing colon after a key.
- Inconsistent indentation (mixing tabs and spaces).
- Unquoted special characters in values.

**Fix:** Validate your YAML before committing:

```bash
python3 -c "import yaml; yaml.safe_load(open('.harness/triggers.yaml'))"
```

Or use an online YAML validator.

### Missing required field

**Symptom:** Terraform plan fails referencing a missing attribute (e.g., `each.value.image_name`).

**Cause:** A trigger entry is missing one of the required fields (`path`, `events`, or `image_name`).

**Fix:** Ensure every entry has all three fields:

```yaml
triggers:
  - path: "apps/api/**"      # Required
    events: [pr, main]       # Required
    image_name: api-service   # Required
```

### Duplicate path entries

**Symptom:** Terraform plan fails with `Two different items produced the key "apps_api____"` or similar `for_each` error.

**Cause:** Two entries have the same `path` value, or paths that sanitize to the same key (e.g., `apps/api/**` and `apps/api/` would both become `apps_api____`).

**Fix:** Ensure each `path` value is unique. If you need multiple triggers for the same directory, differentiate the paths (e.g., `apps/api/src/**` vs `apps/api/tests/**`).

---

## General Debugging Tips

### Checking pipeline execution logs

1. Navigate to `Harness_Platform_Management / Solutions_Factory` > Pipelines.
2. Select the pipeline (`create_service`, `trigger_workspace_on_git_file_change`, or `Provision_Workspace`).
3. Go to Execution History.
4. Click on the failed execution to see stage and step logs.

### Checking IACM workspace state

1. Navigate to IACM > Workspaces.
2. Select the workspace (`service_triggers_<name>` or `watcher_<name>`).
3. Check the Executions tab for apply history.
4. Check the Variables tab to confirm inputs are correct.
5. Check the State tab to see current Terraform state.

### Re-running the pipeline

The `create_service` pipeline is fully idempotent. All four stages check for existing resources and skip creation if found. It is safe to re-run with the same inputs after fixing an issue.

### Manual trigger of Workspace A

If auto-apply is broken and you need to apply immediately:

1. Navigate to `Harness_Platform_Management / Solutions_Factory` > Pipelines > `Provision_Workspace`.
2. Click Run.
3. Set the workspace input to `service_triggers_<service_name>` (hyphens replaced with underscores).
4. Run the pipeline.

### Checking API key permissions

The `account.harness_platform_api_key` secret needs the following permissions:
- Pipeline: Create/Edit/Execute (in HSF project)
- Service: Create/Edit (in target projects)
- Trigger: Create/Edit/Delete (in HSF project and target projects)
- Connector: Access (account-level)
- IACM Workspace: Create/Edit (in HSF project)
