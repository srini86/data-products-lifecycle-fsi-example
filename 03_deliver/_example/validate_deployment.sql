-- =============================================================================
-- VALIDATION TESTS: Retail Customer Churn Risk
-- =============================================================================
-- Run these queries after deployment to validate data quality
-- =============================================================================

USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- =============================================================================
-- TEST 1: Row Count Check (min 1000)
-- =============================================================================
SELECT 
    'TEST 1: Row Count' AS test_name,
    CASE WHEN COUNT(*) >= 1000 THEN 'PASS' ELSE 'FAIL' END AS result,
    COUNT(*) AS actual_count,
    1000 AS minimum_required
FROM RETAIL_CUSTOMER_CHURN_RISK;

-- =============================================================================
-- TEST 2: No NULL values in required fields
-- =============================================================================
SELECT 
    'TEST 2: Required Fields Not Null' AS test_name,
    CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    violation_count
FROM (
    SELECT COUNT(*) AS violation_count
    FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE customer_id IS NULL
       OR customer_name IS NULL
       OR churn_risk_score IS NULL
       OR risk_tier IS NULL
       OR primary_risk_driver IS NULL
       OR recommended_intervention IS NULL
       OR score_calculated_at IS NULL
);

-- =============================================================================
-- TEST 3: Customer ID Uniqueness
-- =============================================================================
SELECT 
    'TEST 3: Customer ID Unique' AS test_name,
    CASE WHEN duplicate_count = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    duplicate_count
FROM (
    SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_count
    FROM RETAIL_CUSTOMER_CHURN_RISK
);

-- =============================================================================
-- TEST 4: Churn Score Valid Range (0-100)
-- =============================================================================
SELECT 
    'TEST 4: Churn Score Range' AS test_name,
    CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    violation_count
FROM (
    SELECT COUNT(*) AS violation_count
    FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE churn_risk_score < 0 OR churn_risk_score > 100
);

-- =============================================================================
-- TEST 5: Risk Tier Aligns with Score (BR001)
-- =============================================================================
SELECT 
    'TEST 5: Risk Tier Alignment' AS test_name,
    CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    violation_count
FROM (
    SELECT COUNT(*) AS violation_count
    FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE NOT (
        (risk_tier = 'LOW' AND churn_risk_score BETWEEN 0 AND 25) OR
        (risk_tier = 'MEDIUM' AND churn_risk_score BETWEEN 26 AND 50) OR
        (risk_tier = 'HIGH' AND churn_risk_score BETWEEN 51 AND 75) OR
        (risk_tier = 'CRITICAL' AND churn_risk_score BETWEEN 76 AND 100)
    )
);

-- =============================================================================
-- TEST 6: High Risk Has Driver (BR002)
-- =============================================================================
SELECT 
    'TEST 6: High Risk Has Driver' AS test_name,
    CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    violation_count
FROM (
    SELECT COUNT(*) AS violation_count
    FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE risk_tier IN ('HIGH', 'CRITICAL')
      AND NOT (declining_balance_flag OR reduced_activity_flag OR 
               low_engagement_flag OR complaint_flag OR dormancy_flag)
);

-- =============================================================================
-- TEST 7: Urgent Escalation Only Critical (BR003)
-- =============================================================================
SELECT 
    'TEST 7: Urgent Escalation Check' AS test_name,
    CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    violation_count
FROM (
    SELECT COUNT(*) AS violation_count
    FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE recommended_intervention = 'URGENT_ESCALATION'
      AND risk_tier != 'CRITICAL'
);

-- =============================================================================
-- TEST 8: Valid Enum Values
-- =============================================================================
SELECT 
    'TEST 8: Valid Risk Tiers' AS test_name,
    CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    violation_count
FROM (
    SELECT COUNT(*) AS violation_count
    FROM RETAIL_CUSTOMER_CHURN_RISK
    WHERE risk_tier NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')
);

-- =============================================================================
-- SUMMARY: All Tests
-- =============================================================================
SELECT 
    'SUMMARY' AS test_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN risk_tier = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_count,
    SUM(CASE WHEN risk_tier = 'HIGH' THEN 1 ELSE 0 END) AS high_count,
    SUM(CASE WHEN risk_tier = 'MEDIUM' THEN 1 ELSE 0 END) AS medium_count,
    SUM(CASE WHEN risk_tier = 'LOW' THEN 1 ELSE 0 END) AS low_count,
    ROUND(AVG(churn_risk_score), 2) AS avg_risk_score,
    MAX(score_calculated_at) AS last_refresh
FROM RETAIL_CUSTOMER_CHURN_RISK;
