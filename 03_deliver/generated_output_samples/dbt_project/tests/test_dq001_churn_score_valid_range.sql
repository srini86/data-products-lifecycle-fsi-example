-- =============================================================================
-- DATA QUALITY TEST: Churn risk score must be in valid range (0-100)
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
-- Quality Rule: churn_score_valid_range
-- =============================================================================

SELECT
    customer_id,
    churn_risk_score,
    'DQ001: churn_risk_score out of range (0-100)' AS violation
FROM {{ ref('retail_customer_churn_risk') }}
WHERE churn_risk_score < 0 OR churn_risk_score > 100
