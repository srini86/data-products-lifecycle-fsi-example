-- ============================================================================
-- BUSINESS RULES TESTS: Generated from Data Contract
-- ============================================================================
-- These tests validate the business rules defined in the data contract.
-- They can be run as dbt tests or standalone SQL in Snowflake.
--
-- Contract: retail-customer-churn-risk v1.0.0
-- Source: data_quality.business_rules section
-- ============================================================================

USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- BR001: Risk tier must align with score
-- ============================================================================
-- Description: The risk_tier value must correspond to the churn_risk_score:
--   - LOW tier only when score is 0-25
--   - MEDIUM tier only when score is 26-50
--   - HIGH tier only when score is 51-75
--   - CRITICAL tier only when score is 76-100
-- Severity: ERROR (violations fail the test)
-- ============================================================================

-- Test: Find records that violate the rule
SELECT 
    'BR001' AS rule_id,
    'Risk tier must align with score' AS rule_name,
    customer_id,
    churn_risk_score,
    risk_tier,
    CASE 
        WHEN churn_risk_score <= 25 THEN 'LOW'
        WHEN churn_risk_score <= 50 THEN 'MEDIUM'
        WHEN churn_risk_score <= 75 THEN 'HIGH'
        ELSE 'CRITICAL'
    END AS expected_tier,
    'VIOLATION: Score ' || churn_risk_score || ' should have tier ' || 
        CASE 
            WHEN churn_risk_score <= 25 THEN 'LOW'
            WHEN churn_risk_score <= 50 THEN 'MEDIUM'
            WHEN churn_risk_score <= 75 THEN 'HIGH'
            ELSE 'CRITICAL'
        END || ' but has ' || risk_tier AS issue
FROM RETAIL_CUSTOMER_CHURN_RISK
WHERE NOT (
    (churn_risk_score <= 25 AND risk_tier = 'LOW') OR
    (churn_risk_score > 25 AND churn_risk_score <= 50 AND risk_tier = 'MEDIUM') OR
    (churn_risk_score > 50 AND churn_risk_score <= 75 AND risk_tier = 'HIGH') OR
    (churn_risk_score > 75 AND risk_tier = 'CRITICAL')
);

-- ============================================================================
-- BR002: At least one risk driver must be flagged for HIGH/CRITICAL risk
-- ============================================================================
-- Description: When a customer has HIGH or CRITICAL risk tier, at least one 
-- risk driver flag must be true
-- Severity: ERROR (violations fail the test)
-- ============================================================================

SELECT 
    'BR002' AS rule_id,
    'High risk requires at least one driver flag' AS rule_name,
    customer_id,
    risk_tier,
    churn_risk_score,
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    'VIOLATION: HIGH/CRITICAL risk with no driver flags set' AS issue
FROM RETAIL_CUSTOMER_CHURN_RISK
WHERE risk_tier IN ('HIGH', 'CRITICAL')
  AND NOT (
      declining_balance_flag = TRUE OR
      reduced_activity_flag = TRUE OR
      low_engagement_flag = TRUE OR
      complaint_flag = TRUE OR
      dormancy_flag = TRUE
  );

-- ============================================================================
-- BR003: Urgent escalation only for CRITICAL risk tier
-- ============================================================================
-- Description: URGENT_ESCALATION intervention can only be assigned when
-- the risk_tier is CRITICAL
-- Severity: ERROR (violations fail the test)
-- ============================================================================

SELECT 
    'BR003' AS rule_id,
    'Urgent escalation only for CRITICAL tier' AS rule_name,
    customer_id,
    risk_tier,
    churn_risk_score,
    recommended_intervention,
    'VIOLATION: URGENT_ESCALATION assigned to non-CRITICAL customer' AS issue
FROM RETAIL_CUSTOMER_CHURN_RISK
WHERE recommended_intervention = 'URGENT_ESCALATION'
  AND risk_tier != 'CRITICAL';

-- ============================================================================
-- BR004: Intervention priority must align with risk score
-- ============================================================================
-- Description: Priority assignments must follow the score-based logic
-- Severity: WARNING (violations are logged but don't fail)
-- ============================================================================

SELECT 
    'BR004' AS rule_id,
    'Intervention priority must align with score' AS rule_name,
    customer_id,
    churn_risk_score,
    intervention_priority,
    CASE 
        WHEN churn_risk_score > 75 THEN 1
        WHEN churn_risk_score > 50 THEN 2
        WHEN churn_risk_score > 25 THEN 3
        ELSE 4
    END AS expected_priority,
    'WARNING: Score ' || churn_risk_score || ' should have priority ' ||
        CASE 
            WHEN churn_risk_score > 75 THEN '1'
            WHEN churn_risk_score > 50 THEN '2'
            WHEN churn_risk_score > 25 THEN '3'
            ELSE '4'
        END || ' but has ' || intervention_priority AS issue
FROM RETAIL_CUSTOMER_CHURN_RISK
WHERE NOT (
    (churn_risk_score > 75 AND intervention_priority = 1) OR
    (churn_risk_score > 50 AND churn_risk_score <= 75 AND intervention_priority = 2) OR
    (churn_risk_score > 25 AND churn_risk_score <= 50 AND intervention_priority = 3) OR
    (churn_risk_score <= 25 AND intervention_priority = 4)
);

-- ============================================================================
-- SUMMARY: Count violations per rule
-- ============================================================================

WITH br001_violations AS (
    SELECT COUNT(*) AS cnt FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE NOT (
        (churn_risk_score <= 25 AND risk_tier = 'LOW') OR
        (churn_risk_score > 25 AND churn_risk_score <= 50 AND risk_tier = 'MEDIUM') OR
        (churn_risk_score > 50 AND churn_risk_score <= 75 AND risk_tier = 'HIGH') OR
        (churn_risk_score > 75 AND risk_tier = 'CRITICAL')
    )
),
br002_violations AS (
    SELECT COUNT(*) AS cnt FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE risk_tier IN ('HIGH', 'CRITICAL')
      AND NOT (declining_balance_flag OR reduced_activity_flag OR 
               low_engagement_flag OR complaint_flag OR dormancy_flag)
),
br003_violations AS (
    SELECT COUNT(*) AS cnt FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE recommended_intervention = 'URGENT_ESCALATION' AND risk_tier != 'CRITICAL'
),
br004_violations AS (
    SELECT COUNT(*) AS cnt FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE NOT (
        (churn_risk_score > 75 AND intervention_priority = 1) OR
        (churn_risk_score > 50 AND churn_risk_score <= 75 AND intervention_priority = 2) OR
        (churn_risk_score > 25 AND churn_risk_score <= 50 AND intervention_priority = 3) OR
        (churn_risk_score <= 25 AND intervention_priority = 4)
    )
)

SELECT 
    'BR001' AS rule_id,
    'Risk tier must align with score' AS rule_name,
    'ERROR' AS severity,
    (SELECT cnt FROM br001_violations) AS violations,
    CASE WHEN (SELECT cnt FROM br001_violations) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
UNION ALL
SELECT 
    'BR002',
    'High risk requires driver flag',
    'ERROR',
    (SELECT cnt FROM br002_violations),
    CASE WHEN (SELECT cnt FROM br002_violations) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
UNION ALL
SELECT 
    'BR003',
    'Urgent escalation for CRITICAL only',
    'ERROR',
    (SELECT cnt FROM br003_violations),
    CASE WHEN (SELECT cnt FROM br003_violations) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
UNION ALL
SELECT 
    'BR004',
    'Priority aligns with score',
    'WARNING',
    (SELECT cnt FROM br004_violations),
    CASE WHEN (SELECT cnt FROM br004_violations) = 0 THEN '✅ PASS' ELSE '⚠️ WARNING' END
ORDER BY rule_id;

-- ============================================================================
-- END OF BUSINESS RULES TESTS
-- ============================================================================

