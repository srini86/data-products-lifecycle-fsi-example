-- ============================================================================
-- REFINE: Data Product Evolution - Version 1.0 to 2.0
-- ============================================================================
-- This script demonstrates how to evolve the Retail Customer Churn Risk 
-- data product by ADDING NEW FEATURES based on business feedback.
--
-- SCENARIO: After 6 months of operating v1.0, business requests:
-- 1. Product downgrade tracking (customers reducing holdings)
-- 2. Customer Lifetime Value (CLV) for prioritization
-- 3. Next Best Action confidence score
-- 4. FCA Consumer Duty vulnerability indicator
--
-- The updated contract (churn_risk_data_contract_v2.yaml) can be used
-- in the Streamlit app to generate the new dbt model.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- BUSINESS CONTEXT
-- ============================================================================
/*
After 6 months of operating the Retail Customer Churn Risk product:

1. PRODUCT DOWNGRADE SIGNAL
   - Retention team found that customers reducing product holdings
     (closing savings accounts, canceling cards) are 3x more likely to churn
   - Need: Track product count changes over 90 days

2. CLV-BASED PRIORITIZATION
   - Branch managers need to prioritize high-value customers
   - Current: All CRITICAL customers treated equally
   - Need: Combine risk tier with customer lifetime value

3. ACTION CONFIDENCE
   - Some recommendations work better than others
   - Need: Confidence score to help teams prioritize actions
   - Low confidence = escalate to relationship manager

4. FCA CONSUMER DUTY COMPLIANCE
   - Regulatory requirement to identify vulnerable customers
   - Need: Flag customers showing vulnerability indicators
   - (Low engagement + complaints + financial stress)

DECISION: Evolve to v2.0 with 6 new columns (non-breaking change)
*/


-- ============================================================================
-- STEP 1: ARCHIVE CURRENT VERSION
-- ============================================================================

-- Create versioned archive of v1.0
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
-- STEP 2: CREATE V2.0 WITH NEW FEATURES
-- ============================================================================
-- This SQL demonstrates the evolution. In practice, use the Streamlit app
-- with churn_risk_data_contract_v2.yaml to generate this model.

CREATE OR REPLACE TABLE RETAIL_CUSTOMER_CHURN_RISK_V2 AS
WITH 
-- Get product holdings from 90 days ago (simulated)
product_history AS (
    SELECT 
        customer_id,
        total_products_held AS current_products,
        -- Simulate historical data (in production, join to history table)
        total_products_held + FLOOR(UNIFORM(0, 2, RANDOM())) AS products_90d_ago
    FROM RETAIL_CUSTOMER_CHURN_RISK
),

-- Calculate CLV tier based on relationship value and tenure
clv_calculation AS (
    SELECT 
        customer_id,
        total_relationship_balance,
        relationship_tenure_months,
        -- Simple CLV estimate: balance * tenure factor
        ROUND(
            total_relationship_balance * 
            (1 + LEAST(relationship_tenure_months, 120) / 120.0) * 
            CASE customer_segment
                WHEN 'HIGH_NET_WORTH' THEN 1.5
                WHEN 'AFFLUENT' THEN 1.3
                WHEN 'MASS_AFFLUENT' THEN 1.1
                ELSE 1.0
            END,
            0
        ) AS estimated_clv
    FROM RETAIL_CUSTOMER_CHURN_RISK
),

-- Main transformation with new v2 features
v2_features AS (
    SELECT 
        r.*,
        
        -- NEW: Product downgrade tracking
        ph.products_90d_ago,
        (ph.current_products < ph.products_90d_ago) AS product_downgrade_flag,
        
        -- NEW: Customer Lifetime Value
        c.estimated_clv,
        CASE 
            WHEN c.estimated_clv >= 100000 THEN 'HIGH_VALUE'
            WHEN c.estimated_clv >= 25000 THEN 'MEDIUM_VALUE'
            ELSE 'STANDARD'
        END AS clv_tier,
        
        -- NEW: Vulnerability indicator (FCA Consumer Duty)
        CASE 
            WHEN r.digital_engagement_score < 20 
                 AND r.complaint_flag = TRUE 
                 AND r.declining_balance_flag = TRUE 
            THEN TRUE
            WHEN r.relationship_tenure_months > 120 
                 AND r.digital_engagement_score < 10 
            THEN TRUE  -- Elderly/digitally excluded
            ELSE FALSE
        END AS vulnerability_indicator,
        
        -- NEW: Action confidence score
        -- Higher confidence when multiple signals align
        LEAST(100, GREATEST(0,
            50  -- Base confidence
            + CASE WHEN r.churn_risk_score > 70 THEN 20 ELSE 0 END  -- Strong signal
            + CASE WHEN r.dormancy_flag AND r.declining_balance_flag THEN 15 ELSE 0 END  -- Aligned signals
            + CASE WHEN r.complaint_flag AND r.low_engagement_flag THEN 10 ELSE 0 END
            - CASE WHEN r.churn_risk_score BETWEEN 40 AND 60 THEN 20 ELSE 0 END  -- Uncertain middle
            - CASE WHEN r.primary_risk_driver = 'MULTI_FACTOR' THEN 15 ELSE 0 END  -- Complex case
        )) AS action_confidence_score
        
    FROM RETAIL_CUSTOMER_CHURN_RISK r
    JOIN product_history ph ON r.customer_id = ph.customer_id
    JOIN clv_calculation c ON r.customer_id = c.customer_id
)

SELECT 
    -- Original v1.0 columns
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
    
    -- NEW v2.0 columns
    products_90d_ago AS products_held_90d_ago,
    product_downgrade_flag,
    estimated_clv,
    clv_tier,
    action_confidence_score,
    vulnerability_indicator,
    
    -- Updated metadata
    CURRENT_TIMESTAMP() AS score_calculated_at,
    CURRENT_DATE() AS data_as_of_date,
    '2.0.0' AS model_version
    
FROM v2_features;

-- Add comments for new columns
COMMENT ON COLUMN RETAIL_CUSTOMER_CHURN_RISK_V2.products_held_90d_ago IS 
'Number of products held 90 days ago for downgrade detection';

COMMENT ON COLUMN RETAIL_CUSTOMER_CHURN_RISK_V2.product_downgrade_flag IS 
'TRUE if customer has reduced product holdings in last 90 days';

COMMENT ON COLUMN RETAIL_CUSTOMER_CHURN_RISK_V2.estimated_clv IS 
'Estimated customer lifetime value in GBP';

COMMENT ON COLUMN RETAIL_CUSTOMER_CHURN_RISK_V2.clv_tier IS 
'CLV classification: HIGH_VALUE (>100K), MEDIUM_VALUE (25K-100K), STANDARD (<25K)';

COMMENT ON COLUMN RETAIL_CUSTOMER_CHURN_RISK_V2.action_confidence_score IS 
'Model confidence in recommended_intervention (0-100). Low scores suggest RM escalation';

COMMENT ON COLUMN RETAIL_CUSTOMER_CHURN_RISK_V2.vulnerability_indicator IS 
'FCA Consumer Duty flag - TRUE if customer shows vulnerability signals';


-- ============================================================================
-- STEP 3: CREATE BACKWARD-COMPATIBLE VIEW
-- ============================================================================
-- Existing consumers continue to work with original column set

CREATE OR REPLACE VIEW RETAIL_CUSTOMER_CHURN_RISK AS
SELECT 
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
-- STEP 4: CREATE V2 ENHANCED VIEW FOR NEW CONSUMERS
-- ============================================================================
-- New consumers get the full v2 feature set with derived columns

CREATE OR REPLACE VIEW RETAIL_CUSTOMER_CHURN_RISK_ENHANCED AS
SELECT 
    *,
    
    -- Derived: Priority score combining risk and CLV
    CASE 
        WHEN risk_tier = 'CRITICAL' AND clv_tier = 'HIGH_VALUE' THEN 1
        WHEN risk_tier = 'CRITICAL' THEN 2
        WHEN risk_tier = 'HIGH' AND clv_tier = 'HIGH_VALUE' THEN 3
        WHEN risk_tier = 'HIGH' THEN 4
        WHEN clv_tier = 'HIGH_VALUE' THEN 5
        ELSE 6
    END AS combined_priority,
    
    -- Derived: Action recommendation with confidence
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
-- STEP 5: TRACK LINEAGE
-- ============================================================================

CREATE TABLE IF NOT EXISTS DATA_PRODUCT_LINEAGE (
    lineage_id          VARCHAR(50) DEFAULT UUID_STRING(),
    parent_product      VARCHAR(200),
    parent_version      VARCHAR(20),
    child_product       VARCHAR(200),
    child_version       VARCHAR(20),
    relationship_type   VARCHAR(50),  -- EVOLVED, SPLIT, MERGED, REPLACED
    effective_date      DATE,
    changes             VARIANT,
    PRIMARY KEY (lineage_id)
);

INSERT INTO DATA_PRODUCT_LINEAGE (
    parent_product, parent_version, child_product, child_version, 
    relationship_type, effective_date, changes
) VALUES (
    'RETAIL_CUSTOMER_CHURN_RISK', '1.0.0', 
    'RETAIL_CUSTOMER_CHURN_RISK', '2.0.0',
    'EVOLVED',
    CURRENT_DATE(),
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
        "reason": "Business feedback: Add CLV prioritization, product downgrade tracking, and FCA Consumer Duty compliance"
    }')
);


-- ============================================================================
-- STEP 6: VERIFY EVOLUTION
-- ============================================================================

-- Compare v1 archive vs v2
SELECT 
    'v1.0 (Archive)' AS version,
    COUNT(*) AS customers,
    COUNT(*) AS column_count_approx
FROM RETAIL_CUSTOMER_CHURN_RISK_V1_ARCHIVE

UNION ALL

SELECT 
    'v2.0 (Current)' AS version,
    COUNT(*) AS customers,
    38 AS column_count_approx  -- 32 original + 6 new
FROM RETAIL_CUSTOMER_CHURN_RISK_V2;

-- Sample v2 data with new features
SELECT 
    customer_id,
    customer_name,
    risk_tier,
    churn_risk_score,
    clv_tier,
    estimated_clv,
    product_downgrade_flag,
    action_confidence_score,
    vulnerability_indicator,
    model_version
FROM RETAIL_CUSTOMER_CHURN_RISK_V2
ORDER BY churn_risk_score DESC
LIMIT 10;

-- New feature distribution
SELECT 
    'Product Downgrade' AS feature,
    SUM(CASE WHEN product_downgrade_flag THEN 1 ELSE 0 END) AS flagged_count,
    COUNT(*) AS total,
    ROUND(SUM(CASE WHEN product_downgrade_flag THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct
FROM RETAIL_CUSTOMER_CHURN_RISK_V2

UNION ALL

SELECT 
    'Vulnerability Indicator' AS feature,
    SUM(CASE WHEN vulnerability_indicator THEN 1 ELSE 0 END) AS flagged_count,
    COUNT(*) AS total,
    ROUND(SUM(CASE WHEN vulnerability_indicator THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct
FROM RETAIL_CUSTOMER_CHURN_RISK_V2;

-- CLV tier distribution
SELECT 
    clv_tier,
    COUNT(*) AS customer_count,
    ROUND(AVG(estimated_clv), 0) AS avg_clv,
    ROUND(AVG(churn_risk_score), 1) AS avg_risk_score
FROM RETAIL_CUSTOMER_CHURN_RISK_V2
GROUP BY clv_tier
ORDER BY avg_clv DESC;


-- ============================================================================
-- EVOLUTION COMPLETE
-- ============================================================================
/*
Summary:
1. ✅ Archived v1.0 for audit trail
2. ✅ Created v2.0 with 6 new columns
3. ✅ Backward-compatible view for existing consumers
4. ✅ Enhanced view for new consumers with derived columns
5. ✅ Lineage tracking updated

New Features in v2.0:
- products_held_90d_ago: Historical product count
- product_downgrade_flag: Early warning signal
- estimated_clv: Customer lifetime value
- clv_tier: Value-based prioritization
- action_confidence_score: Model confidence
- vulnerability_indicator: FCA Consumer Duty compliance

Next Steps:
1. Use churn_risk_data_contract_v2.yaml in Streamlit app
2. Generate updated dbt model from new contract
3. Update semantic view with new columns
4. Notify consumers of new features
*/
