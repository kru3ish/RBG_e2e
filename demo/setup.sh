#!/usr/bin/env bash
set -euo pipefail

# Demo setup: creates test repo + target workspace for live demo

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

TEST_REPO="hsf-wiring-test"
TARGET_WORKSPACE="hsf_wiring_test_target"

echo "=== Demo Setup ==="
echo "GitHub user: $GH_USER"
echo "Test repo: $TEST_REPO"
echo "Target workspace: $TARGET_WORKSPACE"

# Step 1: Create test GitHub repo
echo ""
echo ">> Step 1: Creating test GitHub repo '$TEST_REPO'..."
REPO_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/$GH_USER/$TEST_REPO")

if [ "$REPO_EXISTS" = "200" ]; then
  echo "   Repo already exists, skipping creation."
else
  curl -s -X POST \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/user/repos" \
    -d "{
      \"name\": \"$TEST_REPO\",
      \"description\": \"HSF wiring test repo — auto-created for demo\",
      \"private\": false,
      \"auto_init\": true
    }" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"   Created: {d.get('html_url', 'ERROR')}\")"
fi

# Step 2: Seed the repo with .harness/triggers.yaml
echo ""
echo ">> Step 2: Seeding .harness/triggers.yaml..."

TRIGGERS_CONTENT=$(cat <<'YAML_EOF'
triggers:
  - path: "*"
    events: [pr, main]
    image_name: test-image
YAML_EOF
)

ENCODED_CONTENT=$(echo "$TRIGGERS_CONTENT" | base64)

# Check if file exists
FILE_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/$GH_USER/$TEST_REPO/contents/.harness/triggers.yaml")

if [ "$FILE_EXISTS" = "200" ]; then
  echo "   File already exists, getting SHA for update..."
  FILE_SHA=$(curl -s \
    -H "Authorization: token $GH_TOKEN" \
    "https://api.github.com/repos/$GH_USER/$TEST_REPO/contents/.harness/triggers.yaml" | \
    python3 -c "import json,sys; print(json.load(sys.stdin)['sha'])")

  curl -s -X PUT \
    -H "Authorization: token $GH_TOKEN" \
    "https://api.github.com/repos/$GH_USER/$TEST_REPO/contents/.harness/triggers.yaml" \
    -d "{
      \"message\": \"Update triggers.yaml for demo\",
      \"content\": \"$ENCODED_CONTENT\",
      \"sha\": \"$FILE_SHA\"
    }" > /dev/null
  echo "   Updated .harness/triggers.yaml"
else
  curl -s -X PUT \
    -H "Authorization: token $GH_TOKEN" \
    "https://api.github.com/repos/$GH_USER/$TEST_REPO/contents/.harness/triggers.yaml" \
    -d "{
      \"message\": \"Seed triggers.yaml for HSF wiring demo\",
      \"content\": \"$ENCODED_CONTENT\"
    }" > /dev/null
  echo "   Created .harness/triggers.yaml"
fi

# Step 3: Create target IACM workspace
echo ""
echo ">> Step 3: Creating target IACM workspace '$TARGET_WORKSPACE'..."

WS_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "x-api-key: $API_KEY" \
  "$BASE_URL/iacm/api/orgs/$ORG_ID/projects/$PROJECT_ID/workspaces/$TARGET_WORKSPACE?account_id=$ACCOUNT_ID")

if [ "$WS_EXISTS" = "200" ]; then
  echo "   Workspace already exists, skipping."
else
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    "$BASE_URL/iacm/api/orgs/$ORG_ID/projects/$PROJECT_ID/workspaces?account_id=$ACCOUNT_ID" \
    -d "{
      \"identifier\": \"$TARGET_WORKSPACE\",
      \"name\": \"HSF Wiring Test Target\",
      \"description\": \"Demo target workspace — auto-created for HSF wiring test\",
      \"provisioner\": \"opentofu\",
      \"provisioner_version\": \"1.9.0\",
      \"repository\": \"$GH_USER/$TEST_REPO\",
      \"repository_connector\": \"account.github\",
      \"repository_branch\": \"main\",
      \"repository_path\": \"\",
      \"provider_connector\": \"\",
      \"terraform_variables\": {},
      \"environment_variables\": {},
      \"tags\": {
        \"hsf_demo\": \"true\",
        \"purpose\": \"wiring_test_target\"
      }
    }")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    echo "   Workspace created successfully."
  else
    echo "   WARNING: Failed to create workspace (HTTP $HTTP_CODE)"
    echo "   $BODY"
    echo "   You may need to create it manually in the Harness UI."
  fi
fi

echo ""
echo "=== Demo setup complete ==="
echo ""
echo "Created resources:"
echo "  - GitHub repo: https://github.com/$GH_USER/$TEST_REPO"
echo "  - File: .harness/triggers.yaml"
echo "  - Target workspace: $TARGET_WORKSPACE (in $ORG_ID/$PROJECT_ID)"
echo ""
echo "Next steps:"
echo "  1. Run: ./bootstrap/create-pipeline.sh   (create the generic pipeline)"
echo "  2. Follow: demo/README.md                 (run the live demo)"
