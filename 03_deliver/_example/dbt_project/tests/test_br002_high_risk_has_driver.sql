-- =============================================================================
-- BR002: HIGH or CRITICAL risk customers must have at least one risk driver
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
-- 
-- HIGH or CRITICAL risk customers must have at least one risk driver flagged:
-- declining_balance_flag, reduced_activity_flag, low_engagement_flag,
-- complaint_flag, or dormancy_flag
-- =============================================================================

SELECT
    customer_id,
    churn_risk_score,
    risk_tier,
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    'BR002: High risk without any risk driver flagged' AS violation
FROM {{ ref('retail_customer_churn_risk') }}
WHERE risk_tier IN ('HIGH', 'CRITICAL')
  AND NOT (
      declining_balance_flag OR 
      reduced_activity_flag OR 
      low_engagement_flag OR 
      complaint_flag OR 
      dormancy_flag
  )
