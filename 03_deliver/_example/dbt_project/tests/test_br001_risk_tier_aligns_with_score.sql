-- =============================================================================
-- BUSINESS RULES TESTS: Retail Customer Churn Risk
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
-- 
-- These singular tests validate business logic defined in the contract.
-- Run with: dbt test --select test_retail_customer_churn_risk_business_rules
-- =============================================================================

-- -----------------------------------------------------------------------------
-- BR001: Risk tier must align with score
-- -----------------------------------------------------------------------------
-- Risk tier must correspond to churn_risk_score:
-- LOW (0-25), MEDIUM (26-50), HIGH (51-75), CRITICAL (76-100)
-- -----------------------------------------------------------------------------
-- This test returns rows that VIOLATE the rule (should return 0 rows)

SELECT
    customer_id,
    churn_risk_score,
    risk_tier,
    'BR001: Risk tier does not align with score' AS violation
FROM {{ ref('retail_customer_churn_risk') }}
WHERE NOT (
    (risk_tier = 'LOW' AND churn_risk_score BETWEEN 0 AND 25) OR
    (risk_tier = 'MEDIUM' AND churn_risk_score BETWEEN 26 AND 50) OR
    (risk_tier = 'HIGH' AND churn_risk_score BETWEEN 51 AND 75) OR
    (risk_tier = 'CRITICAL' AND churn_risk_score BETWEEN 76 AND 100)
)
