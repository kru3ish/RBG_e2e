# HSF Wiring Pipeline — Live Demo

## Setup (one-time)

### Action
```bash
./demo/setup.sh
```

### Verify
- GitHub repo `hsf-wiring-test` exists with `.harness/triggers.yaml`
- Target workspace `hsf_wiring_test_target` exists in Solutions_Factory

### Action
```bash
./bootstrap/create-pipeline.sh
```

### Verify
- Pipeline `trigger_workspace_on_git_file_change` appears in HSF UI

---

## Live Demo

### 1. Show the generic pipeline

**Action:** Open Harness UI → Harness Platform Management → Solutions Factory → Pipelines → "Trigger Workspace on Git File Change"

**Say out loud:** "This is the reusable primitive. It takes a target workspace, a repo, and file paths — and wires them together with a webhook trigger."

### 2. Run the pipeline

**Action:** Click Run. Enter inputs:
- `target_workspace_id`: `hsf_wiring_test_target`
- `repo_org`: `kru3ish`
- `repo_name`: `hsf-wiring-test`
- `file_paths`: `.harness/triggers.yaml`
- `branch`: `main`

**Verify:** Pipeline completes successfully. Note the output variables.

**Say out loud:** "The pipeline just created a webhook trigger on the Provision_Workspace pipeline, filtered to fire only when `.harness/triggers.yaml` changes in the test repo."

### 3. Verify the trigger exists

**Action:** In Harness UI → Pipelines → Provision Workspace → Triggers tab

**Verify:** A trigger named `trigger_hsf_wiring_test_target_hsf_wiring_test` exists and is enabled.

**Say out loud:** "Here's the trigger. It watches for pushes to main that change triggers.yaml."

### 4. Trigger the auto-apply

**Action:**
```bash
# Create a branch, edit the file, merge to main
cd /tmp
git clone https://github.com/kru3ish/hsf-wiring-test.git
cd hsf-wiring-test
git checkout -b test-trigger
echo "# Updated $(date)" >> .harness/triggers.yaml
git add .harness/triggers.yaml
git commit -m "Test trigger: update triggers.yaml"
git push origin test-trigger
```

Then open a PR in GitHub and merge it to main.

**Wait:** ~15 seconds

### 5. Verify auto-apply

**Action:** In Harness UI → Pipelines → Provision Workspace → Execution History

**Verify:** A new execution appeared, triggered by the webhook (not manually).

**Say out loud:** "The file merge triggered the Provision Workspace pipeline automatically. No human in the loop. This is the wiring primitive working end-to-end."

---

## Rollback

```bash
./demo/teardown.sh
```

Deletes: trigger, target workspace, and test GitHub repo.

### Verify idempotency
```bash
./demo/setup.sh
# Re-run the demo
./demo/teardown.sh
```
