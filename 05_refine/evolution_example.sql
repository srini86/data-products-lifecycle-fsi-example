-- ============================================================================
-- REFINE: Data Product Evolution - Version 1.0 to 2.0
-- ============================================================================
-- This script demonstrates evolving a data product using a contract-first
-- approach. The transformation logic lives in the DATA CONTRACT, not here.
--
-- APPROACH: Single table evolution (simple and clean)
-- 1. Archive current version as snapshot for audit
-- 2. Regenerate dbt model from updated contract (via Streamlit app)
-- 3. Deploy - new columns are added to the existing table
-- 4. Update monitoring for new columns
--
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- BUSINESS CONTEXT
-- ============================================================================
/*
After 6 months of operating v1.0, business requests new features:

1. PRODUCT DOWNGRADE SIGNAL - Early warning for churn
2. CUSTOMER LIFETIME VALUE - Prioritization for retention team
3. ACTION CONFIDENCE - Identify cases needing human review
4. VULNERABILITY INDICATOR - FCA Consumer Duty compliance

EVOLUTION PROCESS:
1. Archive current version (audit trail)
2. Update the data contract (churn_risk_data_contract_v2.yaml)
3. Regenerate dbt model via Streamlit app
4. Deploy the updated model (adds new columns to existing table)
5. Update monitoring for new columns
*/


-- ============================================================================
-- STEP 1: ARCHIVE CURRENT VERSION (Audit Snapshot)
-- ============================================================================
-- Before evolving, preserve current state for audit and potential rollback

CREATE TABLE IF NOT EXISTS RETAIL_CUSTOMER_CHURN_RISK_V1_SNAPSHOT AS
SELECT 
    *,
    '1.0.0' AS snapshot_version,
    CURRENT_TIMESTAMP() AS snapshot_at,
    'Pre-evolution snapshot before v2.0 upgrade' AS snapshot_reason
FROM RETAIL_CUSTOMER_CHURN_RISK;

COMMENT ON TABLE RETAIL_CUSTOMER_CHURN_RISK_V1_SNAPSHOT IS 
'Audit snapshot of v1.0.0 taken before evolution to v2.0. 
Contains 32 columns. Use for compliance audit or rollback if needed.';

SELECT 'Step 1 Complete: Archived ' || COUNT(*) || ' rows to V1_SNAPSHOT' AS status
FROM RETAIL_CUSTOMER_CHURN_RISK_V1_SNAPSHOT;


-- ============================================================================
-- STEP 2: UPDATE DATA CONTRACT
-- ============================================================================
/*
The v2 contract is already prepared: 05_refine/churn_risk_data_contract_v2.yaml

Key additions in v2 contract:
- products_held_90d_ago: Track product count from 90 days ago
- product_downgrade_flag: True if customer reduced products
- estimated_clv: Customer lifetime value estimate
- clv_tier: HIGH_VALUE / MEDIUM_VALUE / STANDARD
- action_confidence_score: Model confidence (0-100)
- vulnerability_indicator: FCA Consumer Duty flag

The contract defines derivation logic, quality rules, and masking for each.
*/


-- ============================================================================
-- STEP 3: GENERATE V2 MODEL FROM CONTRACT
-- ============================================================================
/*
Use the Streamlit dbt Generator app:

1. Open: Snowsight → Projects → Streamlit → dbt_code_generator
2. Paste contents of: 05_refine/churn_risk_data_contract_v2.yaml
3. Click "Generate All Outputs"
4. Download the generated SQL

The app + Cortex LLM generates the complete dbt model from the contract.
*/


-- ============================================================================
-- STEP 4: DEPLOY UPDATED MODEL
-- ============================================================================
/*
Deploy the generated model using one of these methods:

Option A: dbt Project (Recommended)
  - Add generated SQL to dbt models folder
  - Run: dbt run --select retail_customer_churn_risk
  - The model creates/replaces the table with new columns

Option B: Direct SQL
  - Copy generated SQL from Streamlit app
  - Run in Snowsight worksheet
  - The CREATE OR REPLACE TABLE adds all columns including new ones

After deployment, the table will have 38 columns (32 original + 6 new).
*/

-- Verify table structure after deployment (run after Step 4)
-- DESCRIBE TABLE RETAIL_CUSTOMER_CHURN_RISK;


-- ============================================================================
-- STEP 5: TRACK LINEAGE
-- ============================================================================
-- Record the evolution for governance and audit

CREATE TABLE IF NOT EXISTS DATA_PRODUCT_LINEAGE (
    lineage_id          VARCHAR(50) DEFAULT UUID_STRING(),
    product_name        VARCHAR(200),
    from_version        VARCHAR(20),
    to_version          VARCHAR(20),
    evolution_type      VARCHAR(50),
    evolution_date      DATE,
    contract_file       VARCHAR(200),
    changes             VARIANT,
    PRIMARY KEY (lineage_id)
);

INSERT INTO DATA_PRODUCT_LINEAGE (
    product_name, from_version, to_version, 
    evolution_type, evolution_date, contract_file, changes
) VALUES (
    'RETAIL_CUSTOMER_CHURN_RISK', 
    '1.0.0', 
    '2.0.0',
    'ADDITIVE',
    CURRENT_DATE(),
    '05_refine/churn_risk_data_contract_v2.yaml',
    PARSE_JSON('{
        "new_columns": [
            "products_held_90d_ago",
            "product_downgrade_flag", 
            "estimated_clv",
            "clv_tier",
            "action_confidence_score",
            "vulnerability_indicator"
        ],
        "removed_columns": [],
        "breaking_changes": false,
        "generated_by": "Streamlit dbt Generator App",
        "business_reason": "Add CLV prioritization, product downgrade tracking, FCA Consumer Duty compliance"
    }')
);


-- ============================================================================
-- STEP 6: UPDATE MONITORING FOR NEW COLUMNS
-- ============================================================================
-- Add data quality checks for new v2 columns

-- Null checks on new columns (should always have values)
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (estimated_clv)
    EXPECTATION no_null_clv (VALUE = 0);

ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (clv_tier)
    EXPECTATION no_null_clv_tier (VALUE = 0);

ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (action_confidence_score)
    EXPECTATION no_null_confidence (VALUE = 0);

-- Unique count on new dimension (cardinality tracking)
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (clv_tier);


-- ============================================================================
-- STEP 7: VERIFY EVOLUTION
-- ============================================================================

-- Compare snapshot vs current
SELECT 
    'v1.0 (Snapshot)' AS version,
    COUNT(*) AS row_count,
    32 AS column_count,
    MAX(snapshot_at) AS as_of
FROM RETAIL_CUSTOMER_CHURN_RISK_V1_SNAPSHOT

UNION ALL

SELECT 
    'v2.0 (Current)' AS version,
    COUNT(*) AS row_count,
    38 AS column_count,  -- 32 original + 6 new
    MAX(score_calculated_at) AS as_of
FROM RETAIL_CUSTOMER_CHURN_RISK;


-- View evolution history
SELECT 
    product_name,
    from_version || ' → ' || to_version AS evolution,
    evolution_type,
    evolution_date,
    changes:new_columns AS new_columns,
    changes:business_reason::STRING AS reason
FROM DATA_PRODUCT_LINEAGE 
WHERE product_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY evolution_date DESC;


-- Sample new columns (run after model deployment)
SELECT 
    customer_id,
    customer_name,
    churn_risk_score,
    risk_tier,
    -- New v2 columns:
    products_held_90d_ago,
    product_downgrade_flag,
    estimated_clv,
    clv_tier,
    action_confidence_score,
    vulnerability_indicator
FROM RETAIL_CUSTOMER_CHURN_RISK
WHERE risk_tier IN ('CRITICAL', 'HIGH')
ORDER BY estimated_clv DESC
LIMIT 10;


-- ============================================================================
-- EVOLUTION COMPLETE
-- ============================================================================
/*
Summary:
1. ✅ Archived v1.0 snapshot for audit trail
2. ✅ Updated contract with new requirements (v2.yaml)
3. ✅ Generated v2.0 model from contract (via Streamlit app)
4. ✅ Deployed - existing table now has 6 new columns
5. ✅ Tracked evolution in lineage table
6. ✅ Added DMFs for new columns

KEY PRINCIPLE: 
The transformation logic is defined in churn_risk_data_contract_v2.yaml
and generated by the Streamlit app. This script handles deployment only.

To evolve again (v2.0 → v3.0):
1. Archive current version as snapshot
2. Update contract YAML with new requirements  
3. Regenerate code via Streamlit app
4. Deploy and update monitoring
*/
