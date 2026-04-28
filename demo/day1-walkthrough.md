# Day 1 Demo Walkthrough: HSF Create-a-Service

Live demo script for the HSF wiring primitives end-to-end flow.
Format: **Action** / **Verify** / **Say** for each step.

---

## Prerequisites / Setup Checks

Before starting the demo, confirm these are in place.

### Check 1: Session 1 pipeline is deployed

**Action:** Open Harness > Harness_Platform_Management > Solutions_Factory > Pipelines.

**Verify:** `trigger_workspace_on_git_file_change` pipeline exists and has at least one successful execution.

**Say:** "This is our Session 1 primitive -- it wires any Git file change to an IACM workspace apply. It already works standalone."

### Check 2: Bootstrap scripts have been run

**Action:** Confirm locally:

```bash
ls -la bootstrap/create-pipeline.sh bootstrap/deploy.sh
```

Both should have been executed against the account. If not:

```bash
./bootstrap/create-pipeline.sh
./bootstrap/deploy.sh
```

**Verify:** No errors. Both scripts are idempotent.

### Check 3: create_service pipeline exists

**Action:** In Harness UI, confirm `create_service` pipeline is listed under Solutions_Factory.

**Verify:** Pipeline has 4 stages: Scaffold Repo, Create Harness Service, Create Workspace A, Wire Auto Apply.

**Say:** "This is our Create-a-Service orchestration. It calls Session 1 as its last stage."

---

## Day 1 Demo: Create a Service

Pick a unique service name. Convention: `demo-svc-YYYYMMDD` (e.g., `demo-svc-20260420`).

### Step 1: Launch the workflow

**Action:** Either:

- **IDP route:** Go to IDP > Workflows > "Create a Service". Fill in the form.
- **API route:** Execute the pipeline via API:

```bash
SERVICE_NAME="demo-svc-$(date +%Y%m%d)"

curl -s -X POST \
  -H "x-api-key: $HARNESS_PAT" \
  -H "Content-Type: application/yaml" \
  "https://app.harness.io/pipeline/api/pipeline/execute/create_service?accountIdentifier=Qjf4MwsLRUes1w_efM3eIw&orgIdentifier=Harness_Platform_Management&projectIdentifier=Solutions_Factory&moduleType=CI" \
  --data-raw "pipeline:
    identifier: create_service
    variables:
      - name: service_name
        type: String
        value: $SERVICE_NAME
      - name: target_project
        type: String
        value: Solutions_Factory
      - name: target_org
        type: String
        value: Harness_Platform_Management
      - name: repo_org
        type: String
        value: Kru3ish
      - name: pipeline_template_id
        type: String
        value: Build_and_Push
      - name: HARNESS_PLATFORM_KEY
        type: Secret
        value: account.harness_platform_api_key
      - name: GITHUB_TOKEN_SECRET
        type: Secret
        value: account.githubABC"
```

**Inputs:**

| Field | Value |
|-------|-------|
| service_name | `demo-svc-YYYYMMDD` |
| target_project | `Solutions_Factory` |
| target_org | `Harness_Platform_Management` (default) |
| repo_org | `Kru3ish` (default) |
| pipeline_template_id | `Build_and_Push` (default) |

**Say:** "I am creating a new service. I provide a name and a target project. Everything else is automated."

### Step 2: Watch the pipeline execute

**Action:** Open the pipeline execution in Harness UI. Watch all 4 stages go green.

**Say (while waiting):**

- "Stage 1 scaffolds a GitHub repo and seeds it with a triggers.yaml and a Dockerfile."
- "Stage 2 creates a Harness service entity in the target project."
- "Stage 3 creates Workspace A -- an IACM workspace that reads triggers.yaml and provisions Harness triggers and input sets from it."
- "Stage 4 calls our Session 1 primitive to wire a watcher: any future change to triggers.yaml will automatically re-apply Workspace A."

**Verify:** All 4 stages complete with status `Success`. Total time is typically 3-6 minutes.

### Step 3: Verify the GitHub repo

**Action:** Open `https://github.com/Kru3ish/demo-svc-YYYYMMDD`.

**Verify:**
- Repo exists and is public.
- `.harness/triggers.yaml` is present at the root with one trigger entry.
- `Dockerfile` is present.

**Say:** "The repo was created automatically. It already has a triggers.yaml that declares one build trigger watching all paths."

### Step 4: Verify the Harness service

**Action:** In Harness UI, go to Harness_Platform_Management > Solutions_Factory > Services.

**Verify:** A service named `demo-svc-YYYYMMDD` (identifier: `demo_svc_YYYYMMDD`) exists with tags `managed_by: hsf`.

**Say:** "The Harness service was created programmatically. No manual clicking."

### Step 5: Verify Workspace A (service-triggers)

**Action:** Go to IACM > Workspaces in Solutions_Factory.

**Verify:**
- Workspace `service_triggers_demo_svc_YYYYMMDD` exists.
- It points to `modules/service-triggers` in the `RBG_e2e` repo.
- Its last Provision_Workspace execution shows `Success`.

**Say:** "Workspace A reads triggers.yaml from the service repo and creates the actual Harness triggers and input sets. It already applied successfully."

### Step 6: Verify Workspace B (watcher)

**Action:** Still in IACM > Workspaces.

**Verify:** Workspace `watcher_service_triggers_demo_svc_YYYYMMDD_demo_svc_YYYYMMDD` exists (or similar naming pattern from Session 1 output).

**Say:** "Workspace B is the watcher. It was created by Session 1's primitive. Its job is to fire Workspace A whenever triggers.yaml changes."

### Step 7: Verify webhook trigger is registered

**Action:** Go to Pipelines > Provision_Workspace > Triggers tab.

**Verify:** A trigger named `trigger_service_triggers_demo_svc_YYYYMMDD_demo_svc_YYYYMMDD` exists. It watches for Push events on `.harness/triggers.yaml` in the service repo.

**Say:** "A webhook trigger is now registered. When a developer changes triggers.yaml and merges to main, this fires automatically."

### Step 8: Verify input sets and PR/push triggers from Workspace A

**Action:** Go to Pipelines > Build_and_Push > Triggers tab and Input Sets tab.

**Verify:**
- Input sets exist with prefix `input_*` matching the trigger entries from triggers.yaml.
- Push and/or PR triggers exist with prefixes `push_*` and `pr_*`.

**Say:** "These triggers and input sets were created by Workspace A reading triggers.yaml. Each entry in that file becomes a live Harness trigger."

---

## Day 2 Demo: Edit triggers.yaml (GitOps in action)

This is the payoff. Show that a developer can add triggers by editing a YAML file.

### Step 9: Clone the repo and edit triggers.yaml

**Action:**

```bash
SERVICE_NAME="demo-svc-YYYYMMDD"
git clone https://github.com/Kru3ish/$SERVICE_NAME /tmp/$SERVICE_NAME
cd /tmp/$SERVICE_NAME
```

Edit `.harness/triggers.yaml` to add a second entry:

```yaml
triggers:
  - path: "*"
    events: [pr, main]
    image_name: demo-svc-YYYYMMDD
  - path: "services/api/**"
    events: [pr, main]
    image_name: demo-svc-YYYYMMDD-api
```

**Say:** "I am adding a second trigger entry. This says: when files under services/api change, build a second image. I am only editing a YAML file -- no Harness UI."

### Step 10: Commit, PR, and merge

**Action:**

```bash
git checkout -b add-api-trigger
git add .harness/triggers.yaml
git commit -m "Add API service trigger"
git push origin add-api-trigger
```

Then create and merge a PR (via GitHub UI or CLI):

```bash
gh pr create --title "Add API trigger" --body "Day 2 demo" --base main
gh pr merge --merge --auto
```

**Say:** "Normal developer workflow. Create a branch, push, merge the PR."

### Step 11: Wait for automation

**Action:** Wait approximately 30-60 seconds. Watch the Provision_Workspace pipeline in Harness UI.

**Verify:** A new execution of Provision_Workspace appears, triggered by the webhook. The trigger name should match `trigger_service_triggers_*`.

**Say:** "The merge to main triggered the webhook. Workspace A is now re-applying to pick up the new trigger entry."

### Step 12: Verify new triggers appeared

**Action:** After the Provision_Workspace execution completes, go to Build_and_Push > Triggers tab.

**Verify:**
- New triggers and input sets exist for the `services/api/**` path.
- The original `*` path triggers are still present.

**Say:** "Two new triggers appeared -- a push trigger and a PR trigger for the API path. The developer never touched the Harness UI. Merging the YAML file made it happen."

### Step 13: Closing statement

**Say:** "This is the HSF wiring pattern. Session 1 gives us the primitive -- wire any file change to a workspace apply. Session 2 uses that primitive inside a Create-a-Service flow. The result: developers declare their CI triggers in a YAML file, and the platform handles everything else. No tickets, no UI clicking, no waiting on platform teams."

---

## Teardown

When the demo is done, clean up all created resources:

```bash
SERVICE_NAME="demo-svc-YYYYMMDD" ./demo/teardown.sh
```

See `demo/teardown.sh` for details. It removes:

- Webhook triggers (push_*, pr_*, trigger_*)
- Input sets (input_*)
- Harness service
- Workspace A (service_triggers_*)
- Workspace B (watcher_*)
- The watcher trigger from Session 1
- The GitHub repo

The script is idempotent -- safe to run multiple times.
