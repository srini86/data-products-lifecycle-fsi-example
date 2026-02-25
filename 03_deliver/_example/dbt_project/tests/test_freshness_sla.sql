-- =============================================================================
-- FRESHNESS TEST: Data must be refreshed within SLA (24 hours)
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
-- SLA: freshness_hours: 24
-- =============================================================================

SELECT
    MAX(score_calculated_at) AS latest_refresh,
    CURRENT_TIMESTAMP() AS check_time,
    DATEDIFF(hour, MAX(score_calculated_at), CURRENT_TIMESTAMP()) AS hours_since_refresh,
    'FRESHNESS: Data is stale (>24 hours old)' AS violation
FROM {{ ref('retail_customer_churn_risk') }}
HAVING DATEDIFF(hour, MAX(score_calculated_at), CURRENT_TIMESTAMP()) > 24
