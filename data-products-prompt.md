# dbt Data Product Code Generation

## How to Invoke

```
Create a dbt data model based on instructions in data-products-prompt.md, use rules from 01_dbt_generator_app.py. The data contract is at 02_design/churn_risk_data_contract.yaml
```

---

## Instructions

Generate these dbt artifacts from the data contract:

### 1. dbt model SQL (`retail_customer_churn_risk.sql`)
- Join all upstream tables defined in `source.upstream_tables`
- Apply filters specified for each source table
- Implement derivation logic from `schema.properties[].derivation`
- Use Snowflake SQL syntax with CTEs for readability

### 2. dbt schema.yml
- Model and column descriptions
- Tests based on constraints:
  - `required: true` → `not_null`
  - `unique: true` → `unique`
  - `enum: [...]` → `accepted_values`

### 3. masking_policies.sql
- CREATE MASKING POLICY for fields with `masking_policy` defined
- ANALYST role sees full value, others see masked
- Include ALTER TABLE to apply policies

### 4. monitoring_observability.sql
- Create observability script based on data contract

### Note
Use rules from 01_dbt_generator_app.py

### Output Location
Write files to `03_deliver/generated_output/`
