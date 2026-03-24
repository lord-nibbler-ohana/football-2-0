# Plan Core Feature

Plan the next core feature from the GitHub project board, ensuring alignment with already-planned issues.

## Instructions

Follow these steps exactly:

### Step 1: Read all "Planned" core issues for context

First, fetch all project items to understand what has already been planned:

```bash
gh project item-list 2 --owner lord-nibbler-ohana --format json --limit 100
```

From the results, identify ALL items with **Status = "Planned"**. For each planned issue, read its full details:

```bash
gh issue view <issue-number> --repo lord-nibbler-ohana/football-2-0 --json title,body,labels,comments
```

Take note of the implementation plans and decisions in these planned issues — the new plan must be consistent and aligned with them.

### Step 2: Pick the next "Todo" issue

From the same project items list, find all items with **Status = "Todo"** (regardless of labels).

Pick issues in **natural order by issue number** (lowest number first) — this ensures features are planned in the logical sequence they were created.

If no issues are in Todo status, tell the user there are no issues left to plan.

Read the full issue details:

```bash
gh issue view <issue-number> --repo lord-nibbler-ohana/football-2-0 --json title,body,labels,comments
```

### Step 3: Enter Plan Mode and create a detailed implementation plan

Enter Plan Mode. Based on the issue description, the already-planned issues (from Step 1), and the codebase (read CLAUDE.md, relevant scripts, scenes, and tests), create a thorough implementation plan that covers:

- **Goal**: What the feature achieves
- **Dependencies**: Which planned/completed issues this builds on
- **Files to create or modify**: List every file with a summary of changes
- **Architecture decisions**: How it fits the existing pure-logic pattern and node/scene structure
- **Key constants or configuration**: Any new values needed
- **Collision layers / physics**: If applicable
- **Testing strategy**: Which test files to create or update, what to assert
- **Risks and edge cases**: Anything tricky to watch out for
- **Implementation order**: Step-by-step sequence of work

Be specific — reference actual file paths, class names, and function signatures from the codebase. The plan should be detailed enough that someone could implement it without further design work.

Ensure the plan is **aligned and consistent** with all already-planned core issues. If you notice any conflicts or inconsistencies with existing plans, flag them.

### Step 4: Check and update existing planned issues if needed

If during planning you discover that any already-planned issues need updates to stay consistent (e.g., interface changes, new dependencies, revised assumptions), update those issues too:

```bash
gh issue edit <issue-number> --repo lord-nibbler-ohana/football-2-0 --body "<updated body>"
```

Add a comment explaining what changed and why:

```bash
gh issue comment <issue-number> --repo lord-nibbler-ohana/football-2-0 --body "Updated implementation plan to align with issue #<new-issue-number> planning. Changes: <brief description>"
```

### Step 5: Update the GitHub issue with the plan

Update the issue body by appending the plan. Use:

```bash
gh issue edit <issue-number> --repo lord-nibbler-ohana/football-2-0 --body "<updated body with plan appended>"
```

Preserve the original issue body and append the plan under a `## Implementation Plan` heading.

Also add a comment:

```bash
gh issue comment <issue-number> --repo lord-nibbler-ohana/football-2-0 --body "Implementation plan added by Claude Code. Status changed to Planned."
```

### Step 6: Change status to "Planned"

Get the item ID for this issue from the project items list (from Step 1), then update its status:

```bash
gh project item-edit --project-id PVT_kwHOD6rHrM4BSrnu --id <ITEM_ID> --field-id PVTSSF_lAHOD6rHrM4BSrnuzhAJPCc --single-select-option-id 31442027
```

### Step 7: Implement the plan

Exit Plan Mode and implement the feature according to the plan created in Step 3. Follow the implementation order from the plan. After implementation:

- Run syntax checks on all modified/created `.gd` files
- Run relevant tests to verify the implementation works
- Fix any issues found during validation

### Step 8: Change status to "Done"

Update the project item status to "Done" after successful implementation:

```bash
gh project item-edit --project-id PVT_kwHOD6rHrM4BSrnu --id <ITEM_ID> --field-id PVTSSF_lAHOD6rHrM4BSrnuzhAJPCc --single-select-option-id 98236657
```

Add a comment to the issue confirming implementation:

```bash
gh issue comment <issue-number> --repo lord-nibbler-ohana/football-2-0 --body "Implementation completed by Claude Code."
```

### Step 9: Report back

Tell the user:
- Which issue was planned and implemented (number + title + link)
- A brief summary of the plan
- What was implemented (files created/modified)
- Whether any existing planned issues were updated (and what changed)
- Test results
- Confirm the status was changed to Done
