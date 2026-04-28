#!/usr/bin/env bash
set -euo pipefail

# Discovery script for HSF wiring pipeline
# Reads HARNESS_PAT and HARNESS_ACCOUNT_ID from .env or environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load env if present
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a; source "$ROOT_DIR/.env"; set +a
fi

API_KEY="${HARNESS_PAT:?HARNESS_PAT is required}"
ACCOUNT_ID="${HARNESS_ACCOUNT_ID:?HARNESS_ACCOUNT_ID is required}"
BASE_URL="https://app.harness.io"

api() {
  local path="$1"
  shift
  curl -s -H "x-api-key: $API_KEY" "$BASE_URL/$path" "$@"
}

echo "=== Discovering Harness account: $ACCOUNT_ID ==="

# Find HSF org and project
echo ">> Searching for HSF org and project..."
HSF_ORG=""
HSF_PROJECT=""

PROJECTS=$(api "gateway/ng/api/projects?accountIdentifier=$ACCOUNT_ID&pageSize=100")
HSF_PROJECT=$(echo "$PROJECTS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data['data']['content']:
    proj = p['project']
    name = proj['name'].lower()
    if 'solutions' in name and 'factory' in name:
        print(json.dumps({'identifier': proj['identifier'], 'name': proj['name'], 'org': proj['orgIdentifier']}))
        break
" 2>/dev/null || echo "")

if [[ -z "$HSF_PROJECT" ]]; then
  echo "DISCOVERY GAP: No project matching 'Solutions Factory' found"
  exit 1
fi

ORG_ID=$(echo "$HSF_PROJECT" | python3 -c "import json,sys; print(json.load(sys.stdin)['org'])")
PROJECT_ID=$(echo "$HSF_PROJECT" | python3 -c "import json,sys; print(json.load(sys.stdin)['identifier'])")
echo "   Found: org=$ORG_ID project=$PROJECT_ID"

# Find GitHub connectors (account level)
echo ">> Discovering GitHub connectors..."
GH_CONNECTORS=$(api "gateway/ng/api/connectors?accountIdentifier=$ACCOUNT_ID&pageSize=100" | python3 -c "
import json, sys
data = json.load(sys.stdin)
connectors = []
for c in data['data']['content']:
    conn = c['connector']
    if conn['type'] == 'Github':
        connectors.append({
            'identifier': conn['identifier'],
            'name': conn['name'],
            'url': conn['spec'].get('url', ''),
            'type': conn['spec'].get('type', ''),
            'token_ref': conn['spec'].get('authentication', {}).get('spec', {}).get('spec', {}).get('tokenRef', '')
        })
print(json.dumps(connectors, indent=2))
")
echo "   Found: $(echo "$GH_CONNECTORS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" ) GitHub connectors"

# Check build infrastructure (look at existing pipelines)
echo ">> Checking build infrastructure..."
PROVISION_PIPELINE=$(api "pipeline/api/pipelines/Provision_Workspace?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID" | python3 -c "
import json, sys
data = json.load(sys.stdin)
yaml_str = data['data']['yamlPipeline']
if 'type: Cloud' in yaml_str:
    print('Cloud')
elif 'type: KubernetesDirect' in yaml_str:
    print('KubernetesDirect')
else:
    print('Unknown')
")
echo "   Build infra type: $PROVISION_PIPELINE"

# List existing workspaces
echo ">> Listing IACM workspaces..."
WORKSPACES=$(api "iacm/api/orgs/$ORG_ID/projects/$PROJECT_ID/workspaces?account_id=$ACCOUNT_ID&limit=100" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(json.dumps([{'identifier': w['identifier'], 'name': w['name']} for w in data], indent=2))
")
echo "   Found: $(echo "$WORKSPACES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" ) workspaces"

# List existing pipelines
echo ">> Listing existing pipelines..."
PIPELINES=$(api "pipeline/api/pipelines/list?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&projectIdentifier=$PROJECT_ID&page=0&size=50" \
  -X POST -H "Content-Type: application/json" -d '{"filterType":"PipelineSetup"}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(json.dumps([{'identifier': p['identifier'], 'name': p['name']} for p in data['data']['content']], indent=2))
")

# List org-level connectors
echo ">> Listing org-level connectors..."
ORG_CONNECTORS=$(api "gateway/ng/api/connectors?accountIdentifier=$ACCOUNT_ID&orgIdentifier=$ORG_ID&pageSize=100" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(json.dumps([{'identifier': c['connector']['identifier'], 'name': c['connector']['name'], 'type': c['connector']['type']} for c in data['data']['content']], indent=2))
")

# Build discovery.json
echo ">> Writing discovery.json..."
python3 -c "
import json

discovery = {
    'account_id': '$ACCOUNT_ID',
    'hsf_org': '$ORG_ID',
    'hsf_project': '$PROJECT_ID',
    'github_connectors': {
        'account_level': $GH_CONNECTORS
    },
    'connector_map': {
        'kru3ish': 'account.github',
        'default': 'account.github_public'
    },
    'build_infrastructure': {
        'type': '$PROVISION_PIPELINE',
        'os': 'Linux',
        'arch': 'Amd64',
        'note': 'HSF uses Harness Cloud — no Kubernetes connector needed'
    },
    'existing_workspaces': $WORKSPACES,
    'existing_pipelines': $PIPELINES,
    'org_connectors': $ORG_CONNECTORS,
    'discovery_gaps': [
        'No RBMarketplace GitHub connector exists — connector_map will use account.github for all orgs',
        'No IAA GitHub connector exists',
        'No Kubernetes connector — HSF uses Harness Cloud (runtime: Cloud), not K8s'
    ]
}

with open('$ROOT_DIR/discovery.json', 'w') as f:
    json.dump(discovery, f, indent=2)

print('   Written to discovery.json')
"

echo "=== Discovery complete ==="
