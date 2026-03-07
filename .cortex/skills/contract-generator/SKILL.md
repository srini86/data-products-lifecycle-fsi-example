---
name: contract-generator
description: "Generate an ODCS v2.2 data contract YAML from a Data Product Canvas. Use when: starting a new data product, creating a contract from business requirements. Triggers: generate contract, create contract, data contract from canvas."
tools: ["read", "write", "ask_user_question", "snowflake_sql_execute"]
---

# Contract Generator

Generates a complete ODCS v2.2 data contract YAML from a Data Product Canvas (image or markdown). The contract becomes the single source of truth for all downstream code generation.

## When to Use

- Starting a new data product lifecycle (Phase 2: Design)
- The user provides a Data Product Canvas and asks for a contract
- Regenerating a contract after scope changes

## Inputs

- **Data Product Canvas**: `01_discover/data_product_canvas.png` (or `.md`, `.pdf`)
- **Snowflake connection**: To verify source tables exist and get environment details

## Workflow

### Step 1: Read the Data Product Canvas

Read the canvas image/document and extract all 10 sections:

| # | Section | What to Extract |
|---|---------|-----------------|
| 1 | Business Problem | The pain point being solved |
| 2 | Business Value | Expected outcomes and metrics |
| 3 | Risks | What could go wrong |
| 4 | KPIs | How success is measured |
| 5 | Stakeholders | Who consumes the product and how often |
| 6 | Key Entities | Core business objects |
| 7 | Upstream Sources | Source systems and tables |
| 8 | Downstream Dependencies | What consumes this product |
| 9 | Org Impact | Teams affected |
| 10 | Solution Approach | High-level technical approach |

### Step 2: Verify Source Tables in Snowflake

```sql
-- For each source table identified in the canvas:
SELECT COUNT(*) FROM {database}.{raw_schema}.{table_name};
```

Confirm all sources exist and have data.

### Step 3: Get Environment Details

```sql
SELECT
  CURRENT_ORGANIZATION_NAME() AS org,
  CURRENT_ACCOUNT_NAME() AS account,
  CURRENT_USER() AS user_name,
  CURRENT_ROLE() AS role_name;
```

### Step 4: Generate the ODCS v2.2 Contract YAML

The contract must include these sections:

| Section | Purpose |
|---------|---------|
| `apiVersion`, `kind`, `metadata` | Standard ODCS header with name, version, labels |
| `spec.info` | Title, description, owner, contact details |
| `spec.source` | Upstream tables with locations, key columns, filters |
| `spec.target` | Target database, schema, table, warehouse |
| `spec.schema.properties` | Every output column with type, description, derivation logic |
| `spec.quality_rules` | Completeness, uniqueness, range checks, row count thresholds |
| `spec.business_rules` | Cross-column validation rules |
| `spec.sla` | Freshness hours, update frequency, availability target |
| `spec.access` | Classification, restricted/PII columns, authorized roles |
| `spec.lineage` | Input tables to output table mapping |
| `spec.stakeholders` | Consumers with frequency and use cases |

**Column derivation logic is critical** — for each derived column, write the derivation in plain English or pseudo-SQL with thresholds, enum values, and boundary conditions.

**Mark PII columns explicitly** with `pii: true` and `masking_policy` including authorized roles.

### Step 5: Present to User for Review

-> ASK USER: "Here's the data contract. Please review:
  - [N] output columns defined
  - [N] quality rules
  - [N] business rules
  - SLA: [freshness] refresh, [availability]% availability
  - PII columns: [list] with masking policies
  Is this correct? Any changes needed?"

Wait for approval. Iterate if changes are requested.

### Step 6: Save the Contract

Save to `02_design/{data_product_name}_contract.yaml`.

Add intervention comment:
```yaml
# [INTERVENTION] YYYY-MM-DD: Generated from data product canvas
```

## Output

- `02_design/{data_product_name}_contract.yaml` — Complete ODCS v2.2 contract

## Guardrails

- NEVER finalize the contract without user review and approval
- ALWAYS verify source tables exist in Snowflake before including them
- ALWAYS include derivation logic for every derived/computed column
- ALWAYS mark PII columns with `pii: true` and define masking policies
- ALWAYS include quality_rules for: completeness (required columns), uniqueness (PK), row_count
- ALWAYS include at least one business_rule that validates cross-column logic
- Use Snowflake naming conventions: UPPER_SNAKE_CASE for objects
- Contract version starts at "1.0.0" for new products

## Example

See `02_design/_example/churn_risk_data_contract.yaml` for a complete reference contract.
