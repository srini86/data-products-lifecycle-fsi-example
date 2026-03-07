---
name: test-generator
description: "Generate singular dbt test SQL files from contract quality and business rules. Use when: creating dbt tests, adding quality checks, generating test files. Triggers: generate tests, create tests, generate dbt tests, add tests."
tools: ["read", "write", "ask_user_question"]
---

# Test Generator

Generates singular dbt test SQL files from the contract's `quality_rules` and `business_rules`. Each rule that cannot be expressed as a native schema-level test gets its own SQL file. This is a **template-based** skill.

## When to Use

- Phase 3: Deliver — generating dbt test files
- When the user asks to generate or regenerate tests
- As part of the `$data-product-generator` orchestration (Step 4)

## Inputs

- **Contract YAML**: parsed via `$contract-parser`
- **Model name**: the dbt model to test against

## Workflow

### Step 1: Identify Rules That Need Singular Tests

From the contract, identify rules that CANNOT be expressed as schema-level tests:

| Rule Type | Singular Test? | Why |
|-----------|---------------|-----|
| Range check (min/max) | YES | No native dbt test for ranges |
| Business rule (cross-column) | YES | Complex conditions need SQL |
| Row count threshold | YES | Not a column-level test |
| Freshness SLA | YES | Requires timestamp comparison |
| Completeness (NOT NULL) | NO | Use `not_null` in schema.yml |
| Uniqueness | NO | Use `unique` in schema.yml |
| Enum values | NO | Use `accepted_values` in schema.yml |

### Step 2: Generate Test Files

For each rule that needs a singular test, create a SQL file.

**Naming convention**: `test_{rule_id}_{short_description}.sql`

Examples:
- `test_dq001_churn_score_valid_range.sql`
- `test_br001_risk_tier_aligns_with_score.sql`
- `test_freshness_sla.sql`

**Range check template:**
```sql
-- tests/test_{rule_id}_{column}_valid_range.sql
-- Contract rule: {rule.description}
-- Expected: {column} between {minimum} and {maximum}
SELECT *
FROM {{ ref('{model_name}') }}
WHERE {column} < {minimum} OR {column} > {maximum}
```

**Business rule template:**
```sql
-- tests/test_{rule_id}_{short_name}.sql
-- Contract rule: {rule.description}
SELECT *
FROM {{ ref('{model_name}') }}
WHERE NOT ({rule.condition_as_sql})
```

**Row count threshold template:**
```sql
-- tests/test_{rule_id}_minimum_row_count.sql
-- Contract rule: Minimum {threshold} rows expected
SELECT 1
WHERE (SELECT COUNT(*) FROM {{ ref('{model_name}') }}) < {threshold}
```

**Freshness SLA template:**
```sql
-- tests/test_freshness_sla.sql
-- Contract SLA: Data must be fresher than {hours} hours
SELECT *
FROM {{ ref('{model_name}') }}
WHERE {timestamp_column} < DATEADD('hour', -{hours}, CURRENT_TIMESTAMP())
LIMIT 1
```

### Step 3: Present to User

-> ASK USER: "Generated [N] singular test files:
  - [list each file with its rule description]
  
  These complement the [M] schema-level tests in schema.yml.
  Total test coverage: [N+M] tests.
  Review? Any additional tests needed?"

### Step 4: Save Files

Save each test to `03_deliver/dbt_project/tests/{filename}.sql`

## Output

- `03_deliver/dbt_project/tests/*.sql` — One file per singular test

## Guardrails

- NEVER use external packages (dbt_utils, dbt_expectations)
- Every test MUST trace back to a specific contract `quality_rule` or `business_rule`
- Test SQL must return rows that VIOLATE the rule (0 rows = pass)
- Use `{{ ref('{model_name}') }}` to reference the model (not hardcoded table names)
- Add a comment header in each test linking it to the contract rule ID and description
- NEVER duplicate tests already covered by schema-level tests in schema.yml

## Example

See `03_deliver/_example/dbt_project/tests/` for reference test files.
