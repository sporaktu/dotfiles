# Plan: Jira Delivery Data Gathering Script

## Context
Gray maintains sprint-by-sprint delivery presentations for 3 teams (Derecho, Lightning, MarTech). Each team's slide needs: accomplishments, what's next, and an epic table with story/point progress. Currently this data is gathered manually from Jira. This script automates the data gathering using the `go-jira` CLI (already authenticated).

## What the script produces (printed to terminal)

For each team, a report section containing:

1. **Accomplishments** — Stories completed (Done/Closed/Resolved) in the current sprint
2. **What's Next** — Stories currently In Progress or in upcoming sprints
3. **Epic Table** — For each epic committed to in this PI:
   - Epic key + summary (description)
   - Total stories / completed stories
   - Total points / completed points
   - Sprint range (earliest → latest sprint from child stories)

## Teams
| Presentation Name | Jira Project Key |
|---|---|
| Derecho | MA |
| Lightning | TN |
| MarTech | MARTECH |
| ~~Blizzard~~ | _(skip)_ |

## Approach: Python script calling go-jira CLI

**Why Python over pure bash**: The data requires JSON parsing, aggregation by epic, and sprint name sorting. Python 3 is available and makes this clean. The script shells out to `go-jira` for all Jira API calls (leveraging existing auth).

### File to create
- `/Users/gray.karegeannes/Documents/Delivery Management/gather_delivery_data.py`

### Script design

**Configuration block at top of file:**
```python
TEAMS = {
    "Derecho": "MA",
    "Lightning": "TN",
    "MarTech": "MARTECH",
}
PI_START_DATE = "2026-01-14"  # User updates this each PI
DONE_STATUSES = {"Done", "Closed", "Resolved"}
```

**Step 1: Discover custom field IDs (one-time, cached per run)**
- Run `jira fields` and parse output to find:
  - Story Points field ID (e.g., `customfield_10028`)
  - Sprint field ID (e.g., `customfield_10020`)
  - Epic Link field ID (e.g., `customfield_10014`)
- This makes the script portable across Jira instances

**Step 2: For each team, find PI epics**
- JQL: `project = {KEY} AND issuetype = Epic AND (statusCategory != Done OR resolved >= "{PI_START_DATE}")`
- This catches:
  - Epics still in progress
  - Epics completed during the current PI
- Use `jira list` with JSON-ish Go template to get: key, summary, status, description

**Step 3: For each epic, get child stories**
- Use `jira epic list {EPIC_KEY}` with Go template
- Collect: key, summary, status, story points, sprint name
- Handle stories with no points (default 0) and no sprint

**Step 4: Aggregate per epic**
- Count total stories and completed stories (status in DONE_STATUSES)
- Sum total points and completed points
- Extract sprint names from child stories, sort by name pattern to find earliest/latest

**Step 5: Build "Accomplishments" and "What's Next"**
- Accomplishments: stories in DONE_STATUSES that were resolved recently (last 14 days, i.e., ~current sprint window)
- What's Next: stories in non-done statuses, grouped by epic

**Step 6: Print formatted report**
```
══════════════════════════════════════════
  DERECHO (MA)
══════════════════════════════════════════

ACCOMPLISHMENTS (completed this sprint):
  • MA-1234 - Implement user dashboard
  • MA-1235 - Fix login timeout

WHAT'S NEXT:
  • MA-1240 - Add export feature [In Progress]
  • MA-1241 - API rate limiting [To Do]

EPIC TABLE:
┌──────────┬─────────────────────────┬─────────┬────────┬────────┬──────────┬───────────────┐
│ Epic     │ Description             │ Stories │ Done   │ Points │ Done Pts │ Sprint Range  │
├──────────┼─────────────────────────┼─────────┼────────┼────────┼──────────┼───────────────┤
│ MA-100   │ User Management         │ 12      │ 8      │ 45     │ 30       │ 1.1 → 1.3    │
│ MA-101   │ API Modernization       │ 8       │ 3      │ 32     │ 13       │ 1.2 → 1.4    │
└──────────┴─────────────────────────┴─────────┴────────┴────────┴──────────┴───────────────┘
```

### go-jira template for parsing

The script will use a delimiter-based Go template to make parsing reliable:
```
{{range .issues}}{{.key}}|||{{.fields.summary}}|||{{.fields.status.name}}|||{{.fields.status.statusCategory.name}}|||...{{"\n"}}{{end}}
```
Using `|||` as delimiter (unlikely to appear in field values) and parsing in Python with `.split("|||")`.

### Edge cases handled
- Epics with no child stories (show 0/0)
- Stories with no story points (treated as 0)
- Stories not assigned to any sprint (excluded from sprint range)
- Sprint name parsing: extract the `X.Y` portion from `2026-PI1-X.Y-Team` for display

### Running the script
```bash
python3 "/Users/gray.karegeannes/Documents/Delivery Management/gather_delivery_data.py"
```
User updates `PI_START_DATE` at the top of the file each PI.

## Verification
1. Run the script and confirm it connects to Jira (go-jira auth works)
2. Verify epic counts match what's visible in Jira boards
3. Spot-check a few story point totals against Jira
4. Confirm sprint range extraction looks correct
