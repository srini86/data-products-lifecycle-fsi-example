-- =============================================================================
-- BR003: URGENT_ESCALATION intervention only for CRITICAL risk tier
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
-- 
-- The recommended_intervention can only be URGENT_ESCALATION when
-- the risk_tier is CRITICAL.
-- =============================================================================

SELECT
    customer_id,
    churn_risk_score,
    risk_tier,
    recommended_intervention,
    'BR003: URGENT_ESCALATION assigned to non-CRITICAL customer' AS violation
FROM {{ ref('retail_customer_churn_risk') }}
WHERE recommended_intervention = 'URGENT_ESCALATION'
  AND risk_tier != 'CRITICAL'
