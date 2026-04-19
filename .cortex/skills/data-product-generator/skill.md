---
name: data-product-generator
description: "Orchestrate all data product artifact generation from a contract. Use when: generating all artifacts at once, running the full deliver phase. Triggers: generate data product, generate all artifacts, run deliver phase, build data product."
tools: ["read", "write", "ask_user_question", "snowflake_sql_execute", "skill"]
---

# Data Product Generator

Orchestrates the full Phase 3: Deliver pipeline by invoking all generator skills in the correct order. Takes a contract YAML as input and produces a complete set of dbt and governance artifacts.

## When to Use

- Phase 3: Deliver — generating all artifacts from the contract
- When the user asks to generate a complete data product from a contract
- When the user says "generate all artifacts" or "run the deliver phase"

## Inputs

- **Contract YAML path**: e.g., `02_design/{name}_contract.yaml`
- **Snowflake connection**: to verify source tables

## Workflow

### Step 1: Parse the Contract

Invoke `$contract-parser` to read and validate the contract YAML.

Present summary to user:
```
Contract: {name} v{version}
Owner: {owner}
Target: {database}.{schema}.{table}
Columns: {N} total ({M} PII)
Quality Rules: {N}
Business Rules: {N}
SLA: {freshness}h freshness, {frequency} refresh
```

-> ASK USER: "This is the contract summary. Ready to generate all artifacts?"

### Step 2: Generate dbt Model SQL

Invoke `$model-sql-generator` with the parsed contract.

Output: `03_deliver/dbt_project/models/{model_name}.sql`

### Step 3: Generate Schema YML

Invoke `$schema-yml-generator` with the parsed contract.

Output: `03_deliver/dbt_project/models/schema.yml`

### Step 4: Generate Singular Tests

Invoke `$test-generator` with the parsed contract.

Output: `03_deliver/dbt_project/tests/*.sql`

### Step 5: Generate Masking Policies

Invoke `$masking-policy-generator` with the parsed contract.

Output: `03_deliver/dbt_project/masking_policies.sql`

### Step 6: Generate DMF Setup

Invoke `$dmf-setup-generator` with the parsed contract.

Output: `03_deliver/dbt_project/dmf_setup.sql`

### Step 7: Generate Semantic View

Invoke `$semantic-view-generator` with the parsed contract.

Output: `03_deliver/dbt_project/semantic_view.sql`

### Step 8: Generate Marketplace Listing

Invoke `$marketplace-listing-generator` with the parsed contract.

Output: `03_deliver/dbt_project/marketplace_listing.sql`

### Step 9: Generate Project Scaffolding

Create `dbt_project.yml` and `profiles.yml` if they don't already exist.

**dbt_project.yml:**
```yaml
name: '{project_name}'
version: '1.0.0'
config-version: 2
profile: '{profile_name}'

model-paths: ["models"]
test-paths: ["tests"]

vars:
  database: '{DATABASE}'
  schema: '{SCHEMA}'
  raw_schema: '{RAW_SCHEMA}'

models:
  {project_name}:
    +materialized: table
    +tags: [{tags}]
    # Do NOT add +schema here
```

**profiles.yml:**
```yaml
{profile_name}:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: {ORG}-{ACCOUNT_NAME}
      user: {USER}
      role: {ROLE}
      database: {DATABASE}
      warehouse: {WAREHOUSE}
      schema: {SCHEMA}
      threads: 4
```

### Step 10: Present Full Summary

-> ASK USER: "Artifact generation complete. Summary:

| # | Artifact | Path | Lines |
|---|----------|------|-------|
| 1 | dbt Model SQL | models/{model}.sql | {N} |
| 2 | Schema YAML | models/schema.yml | {N} |
| 3 | Singular Tests | tests/*.sql | {N} files |
| 4 | Masking Policies | masking_policies.sql | {N} |
| 5 | DMF Setup | dmf_setup.sql | {N} |
| 6 | Semantic View | semantic_view.sql | {N} |
| 7 | Marketplace Listing | marketplace_listing.sql | {N} |
| 8 | dbt_project.yml | dbt_project.yml | {N} |
| 9 | profiles.yml | profiles.yml | {N} |

Ready to deploy (Phase 4)?"

## Output

Complete dbt project directory:
```
03_deliver/dbt_project/
  dbt_project.yml
  profiles.yml
  models/
    {model_name}.sql
    schema.yml
  tests/
    test_{rule_1}.sql
    test_{rule_2}.sql
    ...
  masking_policies.sql
  dmf_setup.sql
  semantic_view.sql
  marketplace_listing.sql
```

## Guardrails

- ALWAYS parse the contract first before generating any artifacts
- ALWAYS get user approval before starting generation
- Follow the generation ORDER (steps 2-8) — model SQL first since schema.yml references it
- If any step fails, stop and report to the user before continuing
- NEVER skip the masking policy or DMF steps — they are required for governed products
- All guardrails from individual generator skills apply
- Refer to `prompt.md` for standing rules and forbidden patterns

## Error Recovery

If a step fails:
1. Report the specific error to the user
2. Ask if they want to fix and retry, skip, or abort
3. Do not continue to the next step until the user confirms
