# Phase 3: Deliver

## What this phase produces

- **dbt project** — Models, schema docs, and tests derived from the data contract.
- **Masking policies** — Snowflake column-level security from contract PII/sensitivity tags.
- **Data Metric Functions (DMFs)** — Quality checks registered as Snowflake-native monitors.
- **Semantic view / marketplace SQL** — Discoverability and sharing layer.
- **Deployment validation** — Post-deployment verification queries.

## How to use Cortex Code

1. Point CoCo at your data contract from `02_design/`.
2. Use the skills below to generate each artifact.
3. Review, refine, and run `dbt build` to materialize.

```
CoCo Skills:
  data_contract_parser   — Parses the contract into structured metadata
  schema_generator       — Generates dbt schema.yml with docs and tests
  test_generator         — Generates custom dbt test SQL files
```

## Code Generator App

`01_code_generator_service.py` is a Streamlit-in-Snowflake app that wraps the generation pipeline into a UI. Deploy it to Snowflake for a self-service experience.

## Reference example

See `_example/` for a complete set of generated artifacts for the FSI churn-risk data product:

```
_example/
  dbt_project/                    — Full dbt project (models, tests, profiles)
  02_data_quality_dmf.sql         — Data Metric Functions
  03_semantic_view_marketplace.sql — Semantic view and listing
  masking_policies.sql            — Column-level masking
  validate_deployment.sql         — Post-deploy checks
  retail_customer_churn_risk.sql  — Standalone model SQL
  schema.yml                      — Standalone schema docs
  dmf_setup.sql                   — DMF setup script
```
