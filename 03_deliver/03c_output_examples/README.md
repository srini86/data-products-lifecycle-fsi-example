# 03c_output_examples

## What is this folder?

This folder contains **example outputs** from the dbt Code Generator app (`03b_dbt_generator_app.py`).

These files demonstrate what the AI-powered generator produces when given the data contract as input.

## How these files were generated

```
┌─────────────────────────────┐
│  02_design/                 │
│  churn_risk_data_contract   │
│         (INPUT)             │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  03b_dbt_generator_app.py   │
│  (Streamlit in Snowflake)   │
│  - Parses contract YAML     │
│  - Uses Cortex LLM          │
│  - Generates SQL/YAML       │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  03c_output_examples/       │
│         (OUTPUT)            │
│  - retail_customer_churn_   │
│    risk.sql (dbt model)     │
│  - schema.yml (dbt tests)   │
│  - masking_policies.sql     │
└─────────────────────────────┘
```

## Files in this folder

| File | Description |
|------|-------------|
| `retail_customer_churn_risk.sql` | dbt model SQL with transformation logic derived from contract |
| `schema.yml` | dbt schema file with column documentation and tests |
| `masking_policies.sql` | Snowflake masking policies generated from contract definitions |

## Validation

To validate these outputs match what the generator produces:

1. Deploy `03b_dbt_generator_app.py` to Snowflake as a Streamlit app
2. Upload `02_design/churn_risk_data_contract.yaml` to a Snowflake stage
3. Run the generator with the contract as input
4. Compare generated output with files in this folder

## Note

These are **reference outputs** showing the expected result. The actual generator may produce slightly different SQL based on Cortex LLM responses, but the structure and logic should match the contract's `derivation` specifications.

