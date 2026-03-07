---
name: schema-yml-generator
description: "Generate a dbt schema.yml from an ODCS v2.2 data contract. Use when: creating dbt schema with sources, columns, and tests. Triggers: generate schema, create schema.yml, generate schema yaml."
tools: ["read", "write", "ask_user_question"]
---

# Schema YML Generator

Generates a dbt `schema.yml` file by deterministically parsing the contract's source tables, column definitions, and quality rules into dbt-native test declarations. This is a **template-based** skill — identical input always produces identical output.

## When to Use

- Phase 3: Deliver — generating the dbt schema definition
- When the user asks to generate or regenerate schema.yml
- As part of the `$data-product-generator` orchestration (Step 3)

## Inputs

- **Contract YAML**: parsed via `$contract-parser`

## Workflow

### Step 1: Parse the Contract

Extract:
- Source tables: name, database, schema, key columns
- Output columns: name, type, description, constraints (required, unique, enum values)
- Quality rules that map to schema-level tests

### Step 2: Generate Sources Block

```yaml
version: 2

sources:
  - name: {raw_schema_name}
    database: "{{ var('database') }}"
    schema: "{{ var('raw_schema') }}"
    description: {source_description}
    tables:
      # One entry per upstream_table in the contract
      - name: {table_name}
        description: {table_description}
        columns:
          - name: {key_column}
            description: {description}
            data_tests:
              - unique
              - not_null
```

### Step 3: Generate Model Block

```yaml
models:
  - name: {model_name}
    description: {from contract info.description}
    columns:
      # One entry per schema.properties column
      - name: {column_name}
        description: {from contract}
        data_tests:
          # Map contract constraints to native dbt tests:
```

**Test mapping rules:**

| Contract Constraint | dbt Test |
|--------------------|----------|
| `required: true` or column in completeness rule | `not_null` |
| `unique: true` or primary key | `unique` |
| `enum: [values]` | `accepted_values: values: [...]` |
| Range (min/max) | Do NOT use here — use singular test files via `$test-generator` |
| Business rules | Do NOT use here — use singular test files via `$test-generator` |

### Step 4: Present to User

-> ASK USER: "Generated schema.yml with:
  - [N] source tables defined
  - [N] output columns with descriptions
  - [N] schema-level tests (not_null, unique, accepted_values)
  
  Review? Any changes?"

### Step 5: Save the File

Save to `03_deliver/dbt_project/models/schema.yml`

## Output

- `03_deliver/dbt_project/models/schema.yml` — Complete dbt schema definition

## Guardrails

- Use ONLY native dbt tests: `not_null`, `unique`, `accepted_values`
- NEVER use `dbt_utils` or any external package tests
- NEVER put range checks or business rule checks in schema.yml — those go in singular test files
- Every column in `schema.properties` MUST appear in the schema.yml
- Every source table in the contract MUST appear in the sources block
- Use `data_tests:` (not the deprecated `tests:` key)

## Example

See `03_deliver/_example/dbt_project/models/schema.yml` for a complete reference.
