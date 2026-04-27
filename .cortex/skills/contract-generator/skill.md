---
name: contract-generator
description: "Generate an ODCS v2.2 data contract YAML from a Data Product Canvas or an enterprise AVRO schema. Use when: starting a new data product, creating a contract from business requirements or an existing data model. Triggers: generate contract, create contract, data contract from canvas, data contract from avro, contract from schema."
tools: ["read", "write", "ask_user_question", "snowflake_sql_execute"]
---

# Contract Generator

Generates a complete ODCS v2.2 data contract YAML from either a **Data Product Canvas** (image or markdown) or an **Apache Avro enterprise data model** (`.avsc` file). The contract becomes the single source of truth for all downstream code generation.

## When to Use

- Starting a new data product lifecycle (Phase 2: Design)
- The user provides a Data Product Canvas and asks for a contract
- The user provides an Avro schema (`.avsc`) from a schema registry or data lake catalog
- Regenerating a contract after scope changes

## Inputs — Two Paths

| Path | Input | When to use |
|------|-------|-------------|
| **A — Canvas** | `01_discover/data_product_canvas.png` (or `.md`, `.pdf`) | Human-driven discovery — requirements live in a diagram |
| **B — Avro schema** | `01_discover/enterprise_data_model.avsc` (or any `.avsc`) | Enterprise/platform-driven — schema already exists in a registry or data lake |

Both paths converge at Step 2 (verify tables) and produce the same ODCS v2.2 output.

---

## Workflow — Path A: Data Product Canvas

### Step 1a: Read the Data Product Canvas

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

Then continue to **Step 2**.

---

## Workflow — Path B: Avro Enterprise Data Model

### Step 1b: Read and Parse the Avro Schema

Read the `.avsc` file and extract the following for each `record` type:

| Avro element | Maps to ODCS v2.2 |
|---|---|
| `record.name` | Upstream source table name (UPPER_SNAKE_CASE) |
| `record.namespace` | `metadata.namespace` |
| `record.doc` | Upstream table description in `spec.source.upstream_tables[].description` |
| `field.name` | Output column name in `spec.schema.properties` (UPPER_SNAKE_CASE) |
| `field.type` (primitive) | Snowflake data type — see mapping table below |
| `field.type.logicalType` | Snowflake logical type — see mapping table below |
| `field.doc` | Column `description` in `spec.schema.properties` |
| `field.pii: true` | Set `pii: true` on the column; add entry to `spec.access.restricted_columns` with a masking policy |
| `field.constraints.required: true` | Add `required: true` and a `not_null` quality rule |
| `field.constraints.unique: true` | Add `unique: true` and a `uniqueness` quality rule |
| `field.type` is `enum` | Add `enum` constraint with the symbol list |
| `field.default` | Carry through as column default |

**Avro → Snowflake type mapping:**

| Avro type | logicalType | Snowflake type |
|-----------|-------------|----------------|
| `"string"` | — | `VARCHAR` |
| `"int"` | `date` | `DATE` |
| `"long"` | `timestamp-millis` | `TIMESTAMP_NTZ` |
| `"int"` | — | `INTEGER` |
| `"long"` | — | `BIGINT` |
| `"float"` | — | `FLOAT` |
| `"double"` | — | `DOUBLE` |
| `"boolean"` | — | `BOOLEAN` |
| `"bytes"` | `decimal` | `NUMBER(precision, scale)` |
| `["null", T]` (union) | — | nullable `T` |
| `{"type":"enum","symbols":[...]}` | — | `VARCHAR` + enum constraint |

**PII handling:**
- Any field with `"pii": true` in the Avro field properties must be flagged as `pii: true` in the contract
- Add a masking policy entry: `masking_policy: { policy_name: "{FIELD_NAME}_MASK", authorized_roles: ["DATA_STEWARD", "COMPLIANCE"] }`
- Add the column to `spec.access.restricted_columns`

**Derivation logic:**
- For source fields that map 1:1 to output columns: `source: "{TABLE}.{field_name}"`, `derivation: "Direct mapping from {TABLE}.{field_name}"`
- For aggregated or computed output columns not directly in Avro: infer derivation from `field.doc` descriptions across related records (e.g. a `churn_risk_score` column is derived from signals across Customer, Transaction, DigitalEngagement, and Complaints records)

Then continue to **Step 2**.

---

## Common Steps (both paths)

### Step 2: Verify Source Tables in Snowflake

```sql
-- For each source table identified (from canvas or Avro record names):
SELECT COUNT(*) FROM {database}.{raw_schema}.{table_name};
```

Confirm all sources exist and have data before proceeding.

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

Add a header comment indicating the source of generation:
- Path A: `# [INTERVENTION] YYYY-MM-DD: Generated from data product canvas`
- Path B: `# [INTERVENTION] YYYY-MM-DD: Generated from Avro enterprise data model (01_discover/enterprise_data_model.avsc)`

### Step 5: Present to User for Review

-> ASK USER: "Here's the data contract. Please review:
  - [N] output columns defined
  - [N] quality rules
  - [N] business rules
  - SLA: [freshness] refresh, [availability]% availability
  - PII columns: [list] with masking policies
  - Source: [Canvas / Avro schema]
  Is this correct? Any changes needed?"

Wait for approval. Iterate if changes are requested.

### Step 6: Save the Contract

Save to `02_design/{data_product_name}_contract.yaml`.

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
- When using Path B (Avro), carry forward ALL `pii: true` annotations — never drop them

## Examples

- Canvas-driven contract: `02_design/_example/churn_risk_data_contract.yaml`
- Avro input: `01_discover/enterprise_data_model.avsc`
