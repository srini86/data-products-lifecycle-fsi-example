---
name: capture-feedback
description: "Capture session errors and lessons into Error Playbook and prompt.md. Use when: session ending, errors were fixed, new patterns discovered, lessons learned. Triggers: capture feedback, session summary, update playbook, lessons learned, bake lessons."
tools: ["read", "edit", "write", "ask_user_question"]
---

# Capture Feedback

Extracts errors encountered and lessons learned during the current session, then bakes them into the Error Playbook and prompt.md Forbidden Patterns so they never recur.

## When to Use

- At the end of any session where errors were encountered and fixed
- When a new anti-pattern is discovered
- When the user asks to capture lessons or update guardrails
- Before ending a significant development session

## Workflow

### Step 1: Review the Session

Scan the current conversation for:
- Errors that were encountered (deploy failures, SQL errors, config issues, test failures)
- Workarounds or fixes that were applied
- Patterns that should be avoided in the future
- New knowledge about tool behavior (e.g., Snowflake-native dbt quirks)

Summarize findings as a list:
```
Errors found in this session:
1. [Error message] → [Root cause] → [Fix applied]
2. ...
```

### Step 2: Present Findings to User

→ ASK USER: "I found the following errors/lessons in this session:
  [list]
  
  Which of these should I capture into the Error Playbook and prompt.md?"

Wait for user approval. Do not proceed without confirmation.

### Step 3: Update the Error Playbook

For each approved error, add an entry to the Error Playbook section of `PROMPT_INSTRUCTION_GUIDE.md`.

Use this format:
```markdown
### EN: {Short Descriptive Title}

\```
Error: "{exact error message or symptom}"
\```

**Root Cause**: {Why this happened — 1-2 sentences}

**Fix**: {What resolved it — concrete steps}

**Prevention**: Added to prompt.md Forbidden Patterns
```

Number the entry sequentially (E7, E8, etc.) after existing entries.

### Step 4: Update prompt.md Forbidden Patterns

For each approved error, extract the preventive rule and add it to the `## Forbidden Patterns` section of `prompt.md` at the project root.

Rules should be:
- **Short**: One line, declarative
- **Specific**: Name the exact anti-pattern
- **Actionable**: Say what NOT to do, or what to do instead

Examples of good rules:
```
- CURRENT_ROLE() in masking policies (use IS_ROLE_IN_SESSION() instead)
- env_var() in Snowflake-native profiles.yml (use literal values)
- +schema: in dbt_project.yml models config (causes name concatenation)
```

### Step 5: Update TODO.md

Add a line to TODO.md recording the feedback capture:
```markdown
- [x] Captured [N] lessons from session into Error Playbook and prompt.md
```

### Step 6: Confirm with User

→ ASK USER: "Feedback captured:
  - Error Playbook: [N] new entries added (E{X} through E{Y})
  - prompt.md: [N] new Forbidden Patterns added
  - TODO.md: Updated
  
  Review the additions?"

## Guardrails

- NEVER update Error Playbook or prompt.md without user approval
- NEVER remove existing entries — only append new ones
- ALWAYS use the exact error message from the session (don't paraphrase)
- ALWAYS add an [INTERVENTION] comment with the date when editing files
- If no errors were found in the session, say so and ask if the user has any manual observations to capture
- If prompt.md does not exist yet, create it using the reference template from PROMPT_INSTRUCTION_GUIDE.md Section 2

## File Locations

| File | Purpose | Section to Update |
|------|---------|-------------------|
| `PROMPT_INSTRUCTION_GUIDE.md` | Error Playbook | Section 13 (append new E{N} entries) |
| `prompt.md` (project root) | Forbidden Patterns | `## Forbidden Patterns` section |
| `TODO.md` (project root) | Progress tracking | Add completion line |
