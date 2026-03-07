---
name: contract-verifier
description: "Validate a deployed data product against its contract quality gates. Use when: after deployment, checking data quality, running validation. Triggers: verify contract, validate data product, run quality gates, check quality."
tools: ["read", "snowflake_sql_execute", "ask_user_question"]
---

# Contract Verifier

Runs comprehensive validation queries against a deployed data product to confirm it meets all quality gates defined in the ODCS v2.2 contract. This is Phase 5: Validate.

## When to Use

- After `dbt run` and `dbt test` complete successfully (Phase 4 -> Phase 5)
- When the user asks to validate or verify a data product
- When re-verifying after a contract change or model update
- As part of the `$data-product-generator` orchestration

## Inputs

- **Contract YAML path**: e.g., `02_design/{name}_contract.yaml`
- **Target table**: fully qualified name (database.schema.table)

## Workflow

### Step 1: Parse the Contract

Use `$contract-parser` logic to extract quality_rules, business_rules, SLA, and access control definitions.

### Step 2: Run Quality Gate Checks

Execute each check against the deployed table:

**2a. Completeness — Required columns have 0 NULLs**
```sql
SELECT
  COUNT_IF({column} IS NULL) AS null_{column}
FROM {database}.{schema}.{table};
```
Run for every column marked `required` in the contract.

**2b. Uniqueness — Primary key has 0 duplicates**
```sql
SELECT {primary_key}, COUNT(*) AS cnt
FROM {database}.{schema}.{table}
GROUP BY {primary_key}
HAVING COUNT(*) > 1;
```

**2c. Range Validation — Score/range columns within bounds**
```sql
SELECT MIN({column}), MAX({column}), AVG({column})
FROM {database}.{schema}.{table};
```
Compare against contract's `minimum` and `maximum` values.

**2d. Enum Validation — Enum columns have only allowed values**
```sql
SELECT DISTINCT {column}
FROM {database}.{schema}.{table}
WHERE {column} NOT IN ({allowed_values});
```

**2e. Row Count — Meets minimum threshold**
```sql
SELECT COUNT(*) FROM {database}.{schema}.{table};
```
Compare against contract's `row_count` minimum.

**2f. Business Rules — 0 violations**
```sql
-- For each business_rule in the contract:
SELECT COUNT(*) AS violations
FROM {database}.{schema}.{table}
WHERE NOT ({rule.condition});
```

**2g. Category Distribution**
```sql
SELECT {category_column}, COUNT(*) AS cnt,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM {database}.{schema}.{table}
GROUP BY {category_column}
ORDER BY cnt DESC;
```

### Step 3: Verify Governance Objects

**3a. Masking Policies**
```sql
SELECT *
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => '{database}.{schema}.{table}',
  REF_ENTITY_DOMAIN => 'TABLE'
));
```
Confirm each PII column has its masking policy attached.

**3b. Data Metric Functions**
```sql
SELECT *
FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
  REF_ENTITY_NAME => '{database}.{schema}.{table}',
  REF_ENTITY_DOMAIN => 'TABLE'
));
```
Confirm DMFs are configured per contract quality_rules.

### Step 4: Present Results

-> ASK USER: "Validation results:

| Gate | Status | Details |
|------|--------|---------|
| Completeness | PASS/FAIL | {details} |
| Uniqueness | PASS/FAIL | {details} |
| Range | PASS/FAIL | {details} |
| Enum | PASS/FAIL | {details} |
| Row Count | PASS/FAIL | {count} vs {minimum} |
| Business Rules | PASS/FAIL | {violations} violations |
| Masking | PASS/FAIL | {N}/{M} policies attached |
| DMFs | PASS/FAIL | {N}/{M} functions configured |

Any concerns? Ready to mark validation complete?"

### Step 5: Handle Failures

If any gate fails:
- Report the specific failure with details
- Do NOT mark validation as complete
- Ask the user how to proceed (fix and re-verify, or acknowledge and proceed)

## Output

- Validation report (displayed to user)
- No files written (results are ephemeral)

## Guardrails

- NEVER mark validation as complete if any quality gate fails without user acknowledgment
- ALWAYS run ALL checks — do not skip any gate
- ALWAYS use the contract as the source of truth for thresholds and rules
- If the target table doesn't exist, report the error and suggest running deployment first
- If a specific governance object (policy, DMF) is missing, report which ones are missing
