# Generated Output Examples

This folder contains **validated outputs** from the dbt Code Generator Streamlit app.

## How These Were Generated

```
┌─────────────────────────────┐
│  02_design/                 │
│  churn_risk_data_contract   │
│         (INPUT)             │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  02_dbt_generator_app.py    │
│  (Streamlit in Snowflake)   │
│  - Parses contract YAML     │
│  - Uses Cortex LLM          │
│  - Generates SQL/YAML       │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  03_generated_output/       │
│         (OUTPUT)            │
│  - model SQL                │
│  - schema.yml               │
│  - masking policies         │
│  - business rule tests      │
└─────────────────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `retail_customer_churn_risk.sql` | dbt model with churn risk scoring logic |
| `schema.yml` | dbt schema with 32 columns, descriptions, tests |
| `masking_policies.sql` | Snowflake masking policies for PII |
| `business_rules_tests.sql` | Data quality validation tests |

## Validation Status

These outputs have been **validated** against the data contract:

| Output | Contract Match |
|--------|----------------|
| dbt model derivations | ✅ Verified |
| Masking policy behavior | ✅ 100% match |
| Schema columns & tests | ✅ All 32 columns |
| Business rules | ✅ Verified |

## Usage

These files can be used directly in a Snowflake dbt Project or as reference implementations.
