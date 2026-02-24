-- =============================================================================
-- DATA QUALITY TEST: Digital engagement score must be in valid range (0-100)
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
-- Quality Rule: engagement_score_valid_range
-- =============================================================================

SELECT
    customer_id,
    digital_engagement_score,
    'DQ002: digital_engagement_score out of range (0-100)' AS violation
FROM {{ ref('retail_customer_churn_risk') }}
WHERE digital_engagement_score < 0 OR digital_engagement_score > 100
