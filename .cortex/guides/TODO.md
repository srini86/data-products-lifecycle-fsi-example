# Data Product: Retail Customer Churn Risk

## Progress Tracker

### Phase 1: Design
- [x] Generate data contract (ODCS v2.2 compliant) - `02_design/retail_churn_contract.yaml`
- [x] Review and approve contract

### Phase 2: Deliver (dbt Code Generation)
- [x] Generate dbt model SQL - `03_deliver/models/retail_customer_churn_risk.sql`
- [x] Generate schema.yml - `03_deliver/schema.yml`
- [x] Generate masking policies - `03_deliver/masking_policies.sql`
- [x] Generate DMF setup - `03_deliver/dmf_setup.sql`
- [x] Generate dbt tests - `03_deliver/tests/` (8 test files)
- [x] Create dbt project - `03_deliver/dbt_project/`
- [x] Create deployment scripts - `03_deliver/deploy_model.sql`
- [x] Create validation tests - `03_deliver/validate_deployment.sql`

### Phase 3: Deploy (Direct SQL) - COMPLETED
- [x] Create Snowflake database and schemas (RETAIL_BANKING_DB.RAW, DATA_PRODUCTS)
- [x] Deploy data product table - `RETAIL_CUSTOMER_CHURN_RISK` created
- [x] Apply masking policies - `CUSTOMER_NAME_MASK` applied
- [x] Configure DMF - NULL_COUNT, DUPLICATE_COUNT enabled
- [x] Run initial data load - 984 customers loaded

### Phase 3b: Deploy (Snowflake-native dbt) - COMPLETED
- [x] Prepare dbt project for Snowflake-native deployment
  - [x] Remove `env_var()` and `password` from profiles.yml
  - [x] Set literal account/user values ({your_snowflake_account} / {your_user})
  - [x] Remove `dbt_utils` dependency (replaced with native dbt tests)
  - [x] Remove custom schema override to avoid schema name concatenation
- [x] Deploy via `snow dbt deploy` → `RETAIL_CHURN_RISK` project created
  - VERSION$1: Initial deploy (schema concatenation issue)
  - VERSION$2: Fixed schema targeting → `DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK`
- [x] Execute via `snow dbt execute ... run` → 1 model SUCCESS (984 rows, 1.75s)
- [x] Test via `snow dbt execute ... test` → 34/35 PASS, 1 FAIL (row count 984 < 1000 threshold)

### Phase 4: Validate - COMPLETED
- [x] Run validation tests - 7/8 PASS, 1 WARN (row count 984 vs 1000 threshold)
- [x] Verify data quality metrics
- [x] Validate masking policies applied
- [ ] Test stakeholder access (manual verification needed)

---

## Deployment Summary

**Deployed: 2026-02-23 14:22 PST**

| Metric | Value |
|--------|-------|
| Total Customers | 984 |
| CRITICAL Risk | 4 (0.4%) |
| HIGH Risk | 284 (28.9%) |
| MEDIUM Risk | 413 (42.0%) |
| LOW Risk | 283 (28.8%) |
| Avg Risk Score | 39.02 |

### Test Results

| Test | Result |
|------|--------|
| Row Count (≥1000) | WARN (984) |
| Required Fields Not Null | PASS |
| Customer ID Unique | PASS |
| Churn Score Range (0-100) | PASS |
| Risk Tier Alignment | PASS |
| High Risk Has Driver | PASS |
| Urgent Escalation Check | PASS |
| Valid Risk Tiers | PASS |

### Objects Created

| Object | Type | Location |
|--------|------|----------|
| RETAIL_CUSTOMER_CHURN_RISK | TABLE | RETAIL_BANKING_DB.DATA_PRODUCTS |
| CUSTOMER_NAME_MASK | MASKING POLICY | RETAIL_BANKING_DB.DATA_PRODUCTS |
| DMF: NULL_COUNT | DATA METRIC | customer_id, churn_risk_score, risk_tier |
| DMF: DUPLICATE_COUNT | DATA METRIC | customer_id |
| RETAIL_CHURN_RISK | DBT PROJECT | RETAIL_BANKING_DB.DATA_PRODUCTS (VERSION$2) |

---

## Key Information

| Attribute | Value |
|-----------|-------|
| Owner | Alex Morgan (Analytics) |
| Database | RETAIL_BANKING_DB |
| Schema | DATA_PRODUCTS |
| Target Table | RETAIL_CUSTOMER_CHURN_RISK |
| SLA | Daily refresh by 6 AM UTC |
| Connection | srini-snowflake-ap |
| Version | 1.0.0 |

## Source Tables (RAW schema)
- CUSTOMERS (1,000 rows)
- ACCOUNTS (2,391 rows)
- TRANSACTIONS (22,599 rows)
- DIGITAL_ENGAGEMENT (1,000 rows)
- COMPLAINTS (198 rows)

## Output Columns (32 total)
### Core Outputs
- `churn_risk_score` (0-100)
- `risk_tier` (LOW/MEDIUM/HIGH/CRITICAL)
- `primary_risk_driver`
- `recommended_intervention`
- `intervention_priority` (1-4)

### Risk Driver Flags
- `declining_balance_flag`
- `reduced_activity_flag`
- `low_engagement_flag`
- `complaint_flag`
- `dormancy_flag`

---

## Sample Query

```sql
-- Get high-risk customers needing intervention
SELECT 
    customer_id,
    customer_name,
    churn_risk_score,
    risk_tier,
    primary_risk_driver,
    recommended_intervention
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
WHERE risk_tier IN ('HIGH', 'CRITICAL')
ORDER BY churn_risk_score DESC;
```
