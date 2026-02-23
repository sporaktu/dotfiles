# Azure Subscription Permission Auditor — Implementation Plan

## Context

We need a Python script that audits Azure RBAC permissions across all subscriptions, showing who has what access at subscription and resource group level. The output should be both CSV and JSON, with human-readable principal names resolved via Microsoft Graph API.

**Repo**: `git@github.com:LocumTenens-com/azure-subscription-permission-auditor.git`
**Location**: `~/work/azure-subscription-permission-auditor/`

---

## Step 1: Project Setup

Create directory, init git, add remote:
```
~/work/azure-subscription-permission-auditor/
├── audit_rbac_permissions.py    # Main script (single file)
├── requirements.txt             # Python dependencies
└── .gitignore                   # Python gitignore
```

**Remote**: `git@github.com:LocumTenens-com/azure-subscription-permission-auditor.git`

---

## Step 2: Dependencies (`requirements.txt`)

```
azure-identity>=1.15.0
azure-mgmt-authorization>=4.0.0
azure-mgmt-resource>=23.0.0
msgraph-sdk>=1.2.0
```

| Package | Purpose |
|---------|---------|
| `azure-identity` | `AzureCliCredential` for auth |
| `azure-mgmt-authorization` | Role assignments + definitions API |
| `azure-mgmt-resource` | Subscription + resource group enumeration |
| `msgraph-sdk` | Resolve principal IDs → display names via Graph `getByIds` |

---

## Step 3: Script Structure (`audit_rbac_permissions.py`)

Single-file script, ~400 lines. Functions + one class for Graph resolution.

### CLI Flags (argparse)
| Flag | Purpose |
|------|---------|
| `--subscription` / `-s` | Filter to one subscription (name or ID) |
| `--output-dir` / `-o` | Output directory (default: `.`) |
| `--include-deny` | Include deny assignments (separate CSV) |
| `--no-resolve-names` | Skip Graph API name resolution |
| `--verbose` / `-v` | DEBUG logging |

### Main Flow
```
1. Authenticate (AzureCliCredential, fail fast if not logged in)
2. Enumerate subscriptions (filter if --subscription provided)
3. For each subscription:
   a. Cache role definitions (one API call per sub)
   b. List all role assignments (includes inherited from mgmt groups)
   c. Parse scope → determine level (ManagementGroup/Subscription/ResourceGroup/Resource)
   d. Optionally list deny assignments
4. Gather unique principal IDs across all records
5. Batch-resolve names via Graph getByIds (up to 1000/call) — or skip if --no-resolve-names
6. Write CSV + JSON output files (timestamped)
```

### Key Functions
| Function | Purpose |
|----------|---------|
| `get_credential()` | AzureCliCredential with eager token validation |
| `get_subscriptions()` | Enumerate + optionally filter subscriptions |
| `cache_role_definitions()` | Cache role name/type per subscription |
| `collect_subscription_assignments()` | Role assignments for one sub |
| `collect_deny_assignments()` | Deny assignments for one sub (optional) |
| `collect_all()` | Orchestrate collection with progress indicator |
| `parse_scope()` | Regex-based scope → (level, resource_group) |
| `PrincipalResolver` class | Async Graph getByIds with cache + 429 backoff |
| `resolve_names()` | Sync wrapper that runs async resolution |
| `write_csv()` | CSV output with proper quoting |
| `write_json()` | Structured JSON grouped by subscription |
| `main()` | CLI entry point |

### Output Columns (CSV)
```
SubscriptionName, SubscriptionID, Scope, ScopeLevel, ResourceGroup,
PrincipalID, PrincipalName, PrincipalType, RoleName, RoleType,
AssignmentID, CreatedOn
```

### JSON Structure
```json
{
  "audit_timestamp": "20250211_143000",
  "total_subscriptions": 5,
  "total_assignments": 247,
  "subscriptions": [
    {
      "name": "Production",
      "id": "...",
      "assignment_count": 42,
      "assignments": [{ ... }],
      "deny_assignments": []
    }
  ]
}
```

### Error Handling
- **Not logged in**: Fail immediately with `az login` reminder
- **Subscription not found**: Show available subs, exit
- **One sub fails (403/network)**: Log, skip, continue with others
- **Graph 403 (no permission)**: Warn once, disable resolution, continue with raw IDs
- **Graph 429 (throttle)**: Exponential backoff, 3 retries
- **Deleted principals**: Show `(unresolved)` for name

### Design Decisions
1. **Sync collection, async resolution** — Azure mgmt SDK is sync, Graph SDK is async. Collect everything first, then batch-resolve names in one async pass.
2. **`getByIds` batch** — One Graph call resolves up to 1000 principals. Typical env has 50-200 unique principals = 1 API call total.
3. **Role def cache per sub** — Avoids per-assignment `get_by_id()` calls.
4. **Dataclasses** — Type safety + `asdict()` for serialization.
5. **Sequential subs** — Parallel adds complexity for marginal gain; Graph resolution is the bottleneck anyway.

---

## Step 4: Initial Commit

Commit all three files (`.gitignore`, `requirements.txt`, `audit_rbac_permissions.py`) and push to remote.

---

## Verification

```bash
# Install deps
pip install -r requirements.txt

# Login
az login

# Test single subscription (fast)
python audit_rbac_permissions.py -s "YourSubName" -v

# Test without Graph (if lacking permissions)
python audit_rbac_permissions.py --no-resolve-names

# Full audit
python audit_rbac_permissions.py

# Check output
ls rbac_audit_*.csv rbac_audit_*.json
```
