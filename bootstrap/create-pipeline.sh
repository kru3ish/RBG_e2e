#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script: creates/updates the trigger_workspace_on_git_file_change pipeline in HSF
# Idempotent — if pipeline already exists, updates it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load env
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

# Load discovery
if [[ ! -f "$ROOT_DIR/discovery.json" ]]; then
  echo "ERROR: discovery.json not found. Run scripts/discover.sh first."
  exit 1
fi

API_KEY="${HARNESS_PAT:?HARNESS_PAT is required}"
ACCOUNT_ID="${HARNESS_ACCOUNT_ID:?HARNESS_ACCOUNT_ID is required}"
BASE_URL="https://app.harness.io"

ORG_ID=$(python3 -c "import json; print(json.load(open('$ROOT_DIR/discovery.json'))['hsf_org'])")
PROJECT_ID=$(python3 -c "import json; print(json.load(open('$ROOT_DIR/discovery.json'))['hsf_project'])")

PIPELINE_ID="trigger_workspace_on_git_file_change"
PIPELINE_YAML_FILE="$ROOT_DIR/pipelines/trigger-workspace-on-git-file-change.yaml"

if [[ ! -f "$PIPELINE_YAML_FILE" ]]; then
  echo "ERROR: Pipeline YAML not found at $PIPELINE_YAML_FILE"
  exit 1
fi

PIPELINE_YAML=$(cat "$PIPELINE_YAML_FILE")

echo "=== Bootstrapping pipeline: $PIPELINE_ID ==="
echo "Account: $ACCOUNT_ID"
echo "Org: $ORG_ID"
echo "Project: $PROJECT_ID"

# Check if pipeline exists
EXISTING_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "x-api-key: $API_KEY" \
  "$BASE_URL/pipeline/api/pipelines/$PIPELINE_ID?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID")

if [ "$EXISTING_STATUS" = "200" ]; then
  echo "Pipeline already exists. Updating..."
  # Get current pipeline for If-Match header
  CURRENT=$(curl -s \
    -H "x-api-key: $API_KEY" \
    "$BASE_URL/pipeline/api/pipelines/$PIPELINE_ID?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID")

  # Extract version for If-Match
  VERSION=$(echo "$CURRENT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('data', {}).get('version', 0))" 2>/dev/null || echo "0")

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X PUT \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/yaml" \
    -H "If-Match: $VERSION" \
    "$BASE_URL/pipeline/api/pipelines/$PIPELINE_ID?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID" \
    --data-raw "$PIPELINE_YAML")
else
  echo "Pipeline does not exist. Creating..."
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/yaml" \
    "$BASE_URL/pipeline/api/pipelines/v2?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID" \
    --data-raw "$PIPELINE_YAML")
fi

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "Pipeline $PIPELINE_ID created/updated successfully!"
  echo "View at: https://app.harness.io/ng/account/$ACCOUNT_ID/module/iacm/orgs/$ORG_ID/projects/$PROJECT_ID/pipelines/$PIPELINE_ID/pipeline-studio"
else
  echo "ERROR: Failed (HTTP $HTTP_CODE)"
  echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
  exit 1
fi

echo "=== Bootstrap complete ==="
