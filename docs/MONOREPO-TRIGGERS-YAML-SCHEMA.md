# Monorepo triggers.yaml Schema

This schema defines the `triggers.yaml` file format that Session 2's Workspace A module will consume.
This file lives at `.harness/triggers.yaml` in each service repo.

## Schema

```yaml
triggers:
  - path: string         # glob pattern for path filtering, e.g. "apps/shipping/**" or "*"
    events: [pr, main]   # which events to fire on
    image_name: string   # container image name for this entry
```

## Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | Yes | Glob pattern for path filtering. Use `"*"` to match all paths, or a specific pattern like `"apps/shipping/**"` |
| `events` | list of string | Yes | Events to trigger on. Valid values: `pr` (pull request), `main` (push to main branch) |
| `image_name` | string | Yes | Container image name associated with this trigger entry |

## Examples

### Simple — single service, all paths

```yaml
triggers:
  - path: "*"
    events: [pr, main]
    image_name: my-service
```

### Monorepo — multiple services

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

### PR-only triggers

```yaml
triggers:
  - path: "tests/**"
    events: [pr]
    image_name: test-runner
```

## Usage in Session 2

Session 2's Workspace A Terraform module will:
1. Read this file from the repo
2. Parse each trigger entry
3. Create corresponding Harness triggers and input sets
4. Wire each entry to the appropriate IACM workspace

This file is NOT used by Session 1's wiring pipeline. Session 1 watches for CHANGES to this file.
Session 2 reads its CONTENTS to configure the actual triggers.
