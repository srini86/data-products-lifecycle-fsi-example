-- =============================================================================
-- DATA QUALITY TEST: Minimum customer count
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
-- Quality Rule: minimum_customer_count - min 900 rows
-- =============================================================================

SELECT
    CASE 
        WHEN COUNT(*) < 900 THEN 'FAIL: Row count below minimum (900)'
        ELSE NULL
    END AS violation
FROM {{ ref('retail_customer_churn_risk') }}
HAVING COUNT(*) < 900
