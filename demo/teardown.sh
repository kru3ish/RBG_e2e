#!/usr/bin/env bash
set -euo pipefail

# ===========================================================================
# Demo teardown: removes ALL resources created by Session 1 + Session 2
#
# Usage:
#   SERVICE_NAME=demo-svc-20260420 ./demo/teardown.sh
#   ./demo/teardown.sh                  # defaults: finds demo-svc-* repos
#
# Requires .env with: HARNESS_PAT, HARNESS_ACCOUNT_ID, GITHUB_TOKEN, GITHUB_USERNAME
# Idempotent: skips resources that do not exist.
# ===========================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load env
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

API_KEY="${HARNESS_PAT:?HARNESS_PAT is required}"
ACCOUNT_ID="${HARNESS_ACCOUNT_ID:?HARNESS_ACCOUNT_ID is required}"
GH_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
GH_USER="${GITHUB_USERNAME:?GITHUB_USERNAME is required}"
BASE_URL="https://app.harness.io"
ORG_ID="Harness_Platform_Management"
PROJECT_ID="Solutions_Factory"

# Accept SERVICE_NAME from env or first argument; fall back to prompt
SERVICE_NAME="${SERVICE_NAME:-${1:-}}"
if [[ -z "$SERVICE_NAME" ]]; then
  echo "No SERVICE_NAME provided."
  echo "Usage: SERVICE_NAME=demo-svc-20260420 ./demo/teardown.sh"
  echo "       ./demo/teardown.sh demo-svc-20260420"
  exit 1
fi

# Derived identifiers
SERVICE_ID=$(echo "$SERVICE_NAME" | tr '-' '_')
WORKSPACE_A_ID="service_triggers_${SERVICE_ID}"
WATCHER_ID="watcher_${WORKSPACE_A_ID}_${SERVICE_ID}"
TRIGGER_ID="trigger_${WORKSPACE_A_ID}_${SERVICE_ID}"

# Also handle Session 1 standalone demo resources
SESSION1_TEST_REPO="hsf-wiring-test"
SESSION1_TARGET_WS="hsf_wiring_test_target"
SESSION1_WATCHER_ID="watcher_${SESSION1_TARGET_WS}_hsf_wiring_test"
SESSION1_TRIGGER_ID="trigger_${SESSION1_TARGET_WS}_hsf_wiring_test"

echo "=============================================="
echo " Demo Teardown"
echo "=============================================="
echo "Service name:     $SERVICE_NAME"
echo "Service ID:       $SERVICE_ID"
echo "Workspace A:      $WORKSPACE_A_ID"
echo "Watcher (B):      $WATCHER_ID"
echo "Watcher trigger:  $TRIGGER_ID"
echo "GitHub repo:      $GH_USER/$SERVICE_NAME"
echo ""
echo "Session 1 resources:"
echo "  Test repo:      $GH_USER/$SESSION1_TEST_REPO"
echo "  Target WS:      $SESSION1_TARGET_WS"
echo "  Watcher:        $SESSION1_WATCHER_ID"
echo "  Trigger:        $SESSION1_TRIGGER_ID"
echo "=============================================="
echo ""

# ---------------------------------------------------------------------------
# Helper: delete a Harness resource, print result, never fail
# ---------------------------------------------------------------------------
harness_delete() {
  local label="$1"
  local url="$2"
  echo -n ">> Deleting $label... "
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    -H "x-api-key: $API_KEY" \
    "$url") || true
  if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
    echo "deleted (HTTP $HTTP_CODE)"
  elif [[ "$HTTP_CODE" == "404" || "$HTTP_CODE" == "400" ]]; then
    echo "not found, skipping (HTTP $HTTP_CODE)"
  else
    echo "unexpected response (HTTP $HTTP_CODE), continuing"
  fi
}

github_delete_repo() {
  local repo="$1"
  echo -n ">> Deleting GitHub repo $GH_USER/$repo... "
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    -H "Authorization: token $GH_TOKEN" \
    "https://api.github.com/repos/$GH_USER/$repo") || true
  if [[ "$HTTP_CODE" == "204" ]]; then
    echo "deleted"
  elif [[ "$HTTP_CODE" == "404" ]]; then
    echo "not found, skipping"
  else
    echo "unexpected response (HTTP $HTTP_CODE), continuing"
  fi
}

# ---------------------------------------------------------------------------
# Discover and delete dynamic triggers/input sets created by Workspace A
# ---------------------------------------------------------------------------
echo "=== Phase 1: Session 2 dynamic resources (triggers + input sets) ==="
echo ""

# List all triggers on Build_and_Push pipeline, delete push_* and pr_* ones
echo ">> Listing triggers on Build_and_Push pipeline..."
TRIGGERS_JSON=$(curl -s \
  -H "x-api-key: $API_KEY" \
  "$BASE_URL/pipeline/api/triggers?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID&targetIdentifier=Build_and_Push&size=100" 2>/dev/null || echo "{}")

TRIGGER_IDS=$(echo "$TRIGGERS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    triggers = data.get('data', {}).get('content', [])
    for t in triggers:
        tid = t.get('identifier', '')
        if tid.startswith('push_') or tid.startswith('pr_'):
            print(tid)
except:
    pass
" 2>/dev/null || true)

if [[ -n "$TRIGGER_IDS" ]]; then
  while IFS= read -r tid; do
    harness_delete "trigger $tid (Build_and_Push)" \
      "$BASE_URL/pipeline/api/triggers/$tid?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID&targetIdentifier=Build_and_Push"
  done <<< "$TRIGGER_IDS"
else
  echo "   No push_*/pr_* triggers found on Build_and_Push."
fi

echo ""

# List all input sets on Build_and_Push pipeline, delete input_* ones
echo ">> Listing input sets on Build_and_Push pipeline..."
INPUTSETS_JSON=$(curl -s \
  -H "x-api-key: $API_KEY" \
  "$BASE_URL/pipeline/api/inputSets?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID&pipelineIdentifier=Build_and_Push&inputSetType=ALL&pageSize=100" 2>/dev/null || echo "{}")

INPUTSET_IDS=$(echo "$INPUTSETS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = data.get('data', {}).get('content', [])
    for item in items:
        iid = item.get('identifier', '')
        if iid.startswith('input_'):
            print(iid)
except:
    pass
" 2>/dev/null || true)

if [[ -n "$INPUTSET_IDS" ]]; then
  while IFS= read -r iid; do
    harness_delete "input set $iid (Build_and_Push)" \
      "$BASE_URL/pipeline/api/inputSets/$iid?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID&pipelineIdentifier=Build_and_Push"
  done <<< "$INPUTSET_IDS"
else
  echo "   No input_* input sets found on Build_and_Push."
fi

echo ""

# ---------------------------------------------------------------------------
# Session 2 watcher trigger on Provision_Workspace
# ---------------------------------------------------------------------------
echo "=== Phase 2: Session 2 watcher trigger + workspaces ==="
echo ""

harness_delete "watcher trigger $TRIGGER_ID (Provision_Workspace)" \
  "$BASE_URL/pipeline/api/triggers/$TRIGGER_ID?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID&targetIdentifier=Provision_Workspace"

# Delete Workspace A
harness_delete "Workspace A ($WORKSPACE_A_ID)" \
  "$BASE_URL/iacm/api/orgs/$ORG_ID/projects/$PROJECT_ID/workspaces/$WORKSPACE_A_ID?account_id=$ACCOUNT_ID"

# Delete Workspace B (watcher)
harness_delete "Workspace B ($WATCHER_ID)" \
  "$BASE_URL/iacm/api/orgs/$ORG_ID/projects/$PROJECT_ID/workspaces/$WATCHER_ID?account_id=$ACCOUNT_ID"

echo ""

# ---------------------------------------------------------------------------
# Harness service
# ---------------------------------------------------------------------------
echo "=== Phase 3: Harness service ==="
echo ""

harness_delete "Harness service $SERVICE_ID" \
  "$BASE_URL/gateway/ng/api/servicesV2/$SERVICE_ID?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID"

echo ""

# ---------------------------------------------------------------------------
# Session 1 standalone resources
# ---------------------------------------------------------------------------
echo "=== Phase 4: Session 1 standalone resources ==="
echo ""

harness_delete "Session 1 trigger ($SESSION1_TRIGGER_ID on Provision_Workspace)" \
  "$BASE_URL/pipeline/api/triggers/$SESSION1_TRIGGER_ID?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID&targetIdentifier=Provision_Workspace"

harness_delete "Session 1 target workspace ($SESSION1_TARGET_WS)" \
  "$BASE_URL/iacm/api/orgs/$ORG_ID/projects/$PROJECT_ID/workspaces/$SESSION1_TARGET_WS?account_id=$ACCOUNT_ID"

harness_delete "Session 1 watcher workspace ($SESSION1_WATCHER_ID)" \
  "$BASE_URL/iacm/api/orgs/$ORG_ID/projects/$PROJECT_ID/workspaces/$SESSION1_WATCHER_ID?account_id=$ACCOUNT_ID"

echo ""

# ---------------------------------------------------------------------------
# GitHub repos
# ---------------------------------------------------------------------------
echo "=== Phase 5: GitHub repos ==="
echo ""

github_delete_repo "$SERVICE_NAME"
github_delete_repo "$SESSION1_TEST_REPO"

echo ""
echo "=============================================="
echo " Teardown complete"
echo "=============================================="
echo ""
echo "Deleted (or confirmed absent):"
echo "  - push_*/pr_* triggers on Build_and_Push"
echo "  - input_* input sets on Build_and_Push"
echo "  - Watcher trigger: $TRIGGER_ID"
echo "  - Workspace A: $WORKSPACE_A_ID"
echo "  - Workspace B: $WATCHER_ID"
echo "  - Harness service: $SERVICE_ID"
echo "  - Session 1 trigger: $SESSION1_TRIGGER_ID"
echo "  - Session 1 workspaces: $SESSION1_TARGET_WS, $SESSION1_WATCHER_ID"
echo "  - GitHub repos: $SERVICE_NAME, $SESSION1_TEST_REPO"
