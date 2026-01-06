-- ============================================================================
-- REFINE: Data Product Evolution - Version 1.0 to 2.0
-- ============================================================================
-- This script demonstrates the PROCESS of evolving the data product.
-- 
-- KEY PRINCIPLE: The transformation logic lives in the DATA CONTRACT, not here.
-- Use the Streamlit app with churn_risk_data_contract_v2.yaml to generate
-- the actual dbt model code.
--
-- This script handles:
-- 1. Archiving the previous version
-- 2. Deploying the generated v2 model (from Streamlit output)
-- 3. Creating backward-compatible views
-- 4. Tracking lineage
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

APPROACH:
1. Update the data contract (churn_risk_data_contract_v2.yaml)
2. Use Streamlit app to generate new dbt model from contract
3. Run this script to deploy the evolution
*/


-- ============================================================================
-- STEP 1: ARCHIVE CURRENT VERSION
-- ============================================================================
-- Before deploying v2, preserve v1 for audit and rollback

CREATE TABLE IF NOT EXISTS RETAIL_CUSTOMER_CHURN_RISK_V1_ARCHIVE AS
SELECT 
    *,
    '1.0.0' AS archive_version,
    CURRENT_TIMESTAMP() AS archived_at,
    'Evolved to v2.0 with new features' AS archive_reason
FROM RETAIL_CUSTOMER_CHURN_RISK;

COMMENT ON TABLE RETAIL_CUSTOMER_CHURN_RISK_V1_ARCHIVE IS 
'Archived version 1.0.0 - superseded by v2.0 with CLV, product downgrade, and vulnerability features';


-- ============================================================================
-- STEP 2: GENERATE V2 MODEL FROM CONTRACT
-- ============================================================================
/*
DO NOT hardcode transformation logic here!

Instead:
1. Open the Streamlit dbt Generator app
2. Paste contents of: 05_refine/churn_risk_data_contract_v2.yaml
3. Click "Generate All Outputs"
4. Download: retail_customer_churn_risk.sql (the v2 dbt model)

The contract defines:
- New columns: products_held_90d_ago, product_downgrade_flag, 
  estimated_clv, clv_tier, action_confidence_score, vulnerability_indicator
- Derivation logic for each column
- Data quality rules
- Masking policies

The Streamlit app + Cortex LLM generates the SQL from these specifications.
*/


-- ============================================================================
-- STEP 3: DEPLOY GENERATED MODEL
-- ============================================================================
-- After generating the dbt model from the contract, deploy it:

-- Option A: Run in Snowflake dbt Project
-- dbt run --select retail_customer_churn_risk

-- Option B: Execute the generated SQL directly
-- Copy the output from Streamlit and run here:

-- >>> PASTE GENERATED SQL FROM STREAMLIT APP HERE <<<
-- The generated model will create RETAIL_CUSTOMER_CHURN_RISK_V2
-- with all 38 columns (32 original + 6 new from v2 contract)


-- ============================================================================
-- STEP 4: CREATE BACKWARD-COMPATIBLE VIEW
-- ============================================================================
-- Existing consumers continue to work with original column set

CREATE OR REPLACE VIEW RETAIL_CUSTOMER_CHURN_RISK AS
SELECT 
    -- Original v1.0 columns only (for backward compatibility)
    customer_id,
    customer_name,
    customer_segment,
    region,
    relationship_tenure_months,
    total_products_held,
    primary_account_balance,
    total_relationship_balance,
    avg_monthly_transactions_3m,
    transaction_trend,
    balance_trend,
    days_since_last_transaction,
    mobile_app_active,
    login_count_30d,
    digital_engagement_score,
    open_complaints_count,
    complaints_last_12m,
    has_unresolved_complaint,
    churn_risk_score,
    risk_tier,
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    primary_risk_driver,
    risk_drivers_json,
    recommended_intervention,
    intervention_priority,
    score_calculated_at,
    data_as_of_date,
    model_version
FROM RETAIL_CUSTOMER_CHURN_RISK_V2;

COMMENT ON VIEW RETAIL_CUSTOMER_CHURN_RISK IS 
'Backward-compatible view exposing v1.0 schema. 
For new features (CLV, vulnerability, confidence), use RETAIL_CUSTOMER_CHURN_RISK_V2 directly.
Contract version: 2.0.0 | Backward compatible with: 1.0.0';


-- ============================================================================
-- STEP 5: CREATE ENHANCED VIEW FOR NEW CONSUMERS
-- ============================================================================
-- New consumers get full v2 features with derived priority columns

CREATE OR REPLACE VIEW RETAIL_CUSTOMER_CHURN_RISK_ENHANCED AS
SELECT 
    *,
    
    -- Derived: Combined priority (risk + CLV)
    CASE 
        WHEN risk_tier = 'CRITICAL' AND clv_tier = 'HIGH_VALUE' THEN 1
        WHEN risk_tier = 'CRITICAL' THEN 2
        WHEN risk_tier = 'HIGH' AND clv_tier = 'HIGH_VALUE' THEN 3
        WHEN risk_tier = 'HIGH' THEN 4
        WHEN clv_tier = 'HIGH_VALUE' THEN 5
        ELSE 6
    END AS combined_priority,
    
    -- Derived: Final recommendation with confidence check
    CASE 
        WHEN action_confidence_score < 50 THEN 'ESCALATE_TO_RM'
        WHEN vulnerability_indicator THEN 'VULNERABLE_CUSTOMER_PROTOCOL'
        ELSE recommended_intervention
    END AS final_recommendation,
    
    -- Derived: Requires human review flag
    (action_confidence_score < 50 OR vulnerability_indicator) AS requires_human_review
    
FROM RETAIL_CUSTOMER_CHURN_RISK_V2;

COMMENT ON VIEW RETAIL_CUSTOMER_CHURN_RISK_ENHANCED IS 
'Full v2.0 feature set with derived priority and recommendation columns.
Use for retention campaigns and branch operations.';


-- ============================================================================
-- STEP 6: TRACK LINEAGE
-- ============================================================================

CREATE TABLE IF NOT EXISTS DATA_PRODUCT_LINEAGE (
    lineage_id          VARCHAR(50) DEFAULT UUID_STRING(),
    parent_product      VARCHAR(200),
    parent_version      VARCHAR(20),
    child_product       VARCHAR(200),
    child_version       VARCHAR(20),
    relationship_type   VARCHAR(50),
    effective_date      DATE,
    contract_file       VARCHAR(200),
    changes             VARIANT,
    PRIMARY KEY (lineage_id)
);

INSERT INTO DATA_PRODUCT_LINEAGE (
    parent_product, parent_version, child_product, child_version, 
    relationship_type, effective_date, contract_file, changes
) VALUES (
    'RETAIL_CUSTOMER_CHURN_RISK', '1.0.0', 
    'RETAIL_CUSTOMER_CHURN_RISK', '2.0.0',
    'EVOLVED',
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
        "breaking_changes": false,
        "backward_compatible": true,
        "generated_by": "Streamlit dbt Generator App",
        "reason": "Business feedback: Add CLV prioritization, product downgrade tracking, FCA Consumer Duty compliance"
    }')
);


-- ============================================================================
-- STEP 7: UPDATE MONITORING (Apply DMFs to new columns)
-- ============================================================================
-- Add data quality checks for new v2 columns

-- Null checks on new columns
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK_V2
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (estimated_clv);

ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK_V2
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (action_confidence_score);

-- Custom DMF for CLV tier validation
CREATE OR REPLACE DATA METRIC FUNCTION invalid_clv_tier(
    ARG_T TABLE(ARG_C VARCHAR)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM ARG_T
    WHERE ARG_C NOT IN ('HIGH_VALUE', 'MEDIUM_VALUE', 'STANDARD')
$$;

ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK_V2
    ADD DATA METRIC FUNCTION MONITORING.invalid_clv_tier 
    ON (clv_tier);


-- ============================================================================
-- STEP 8: VERIFY EVOLUTION
-- ============================================================================

-- Compare v1 archive vs v2
SELECT 
    'v1.0 (Archive)' AS version,
    COUNT(*) AS customers,
    32 AS column_count
FROM RETAIL_CUSTOMER_CHURN_RISK_V1_ARCHIVE

UNION ALL

SELECT 
    'v2.0 (Current)' AS version,
    COUNT(*) AS customers,
    38 AS column_count  -- 32 original + 6 new
FROM RETAIL_CUSTOMER_CHURN_RISK_V2;

-- View lineage
SELECT * FROM DATA_PRODUCT_LINEAGE 
WHERE child_product = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY effective_date DESC;


-- ============================================================================
-- EVOLUTION COMPLETE
-- ============================================================================
/*
Summary:
1. ✅ Archived v1.0 for audit trail
2. ✅ Generated v2.0 model from contract (via Streamlit app)
3. ✅ Backward-compatible view for existing consumers  
4. ✅ Enhanced view for new consumers
5. ✅ Lineage tracking with contract reference
6. ✅ DMFs applied to new columns

KEY POINT: 
The transformation logic is defined in churn_risk_data_contract_v2.yaml
and generated by the Streamlit app. This script only handles deployment.

To evolve again (v2.0 → v3.0):
1. Update the contract YAML with new requirements
2. Regenerate code via Streamlit app
3. Run deployment script
*/
