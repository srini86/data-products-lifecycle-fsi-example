---
name: contract-parser
description: "Parse an ODCS v2.2 data contract YAML into structured data for downstream skills. Use when: preparing to generate code artifacts from a contract. Triggers: parse contract, read contract, extract contract data."
tools: ["read"]
---

# Contract Parser

Parses an ODCS v2.2 data contract YAML and extracts structured data that downstream generator skills consume. This is a read-only, deterministic operation.

## When to Use

- Before running any generator skill (model-sql, schema-yml, masking-policy, dmf-setup, test, semantic-view, marketplace-listing)
- When the `$data-product-generator` orchestrator needs to prepare input for all generators
- When the user asks to inspect or summarize a contract

## Inputs

- **Contract YAML path**: e.g., `02_design/{name}_contract.yaml`

## Workflow

### Step 1: Read the Contract YAML

Read the full contract file and parse all sections.

### Step 2: Extract Structured Data

Extract and organize the following data structures:

**1. Metadata**
- Product name, version, owner, description, tags
- Target database, schema, table, warehouse, role

**2. Source Tables**
- For each upstream table: name, location (database.schema.table), key columns, filter conditions

**3. Column Definitions**
- For each output column: name, type, description, derivation logic, constraints (required, unique, min, max, enum values)
- Flag which columns are PII (`pii: true`)
- Flag which columns are primary keys

**4. Quality Rules**
- Rule name, type (completeness/uniqueness/range/row_count/freshness), target columns, thresholds

**5. Business Rules**
- Rule name, description, SQL condition, severity

**6. SLA**
- Freshness hours, update frequency, schedule, availability target

**7. Access Control**
- PII columns with masking policy names and authorized roles
- Role tiers (full access, masked, aggregated, metrics-only, no access)

**8. Stakeholders**
- Consumer names, frequency, use cases

### Step 3: Present Summary

Output a concise summary of what was parsed:
```
Contract: {name} v{version}
Owner: {owner}
Target: {database}.{schema}.{table}
Columns: {N} total ({M} PII)
Quality Rules: {N}
Business Rules: {N}
SLA: {freshness}h freshness, {frequency} refresh
```

## Output

Structured data (in-memory) ready for consumption by downstream generator skills. No files are written.

## Guardrails

- This skill is READ-ONLY — it never writes or modifies files
- ALWAYS validate that required sections exist: metadata, source, schema.properties, quality_rules
- WARN the user if any required section is missing or empty
- NEVER assume column types or derivation logic — only use what's in the contract
- If the contract file doesn't exist at the given path, report the error clearly
