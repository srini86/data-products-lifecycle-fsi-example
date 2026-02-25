-- =============================================================================
-- BR004: Intervention priority must align with risk score thresholds
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
-- 
-- Priority assignments must follow the score-based logic:
-- - Priority 1 only when score > 75
-- - Priority 2 only when score 51-75
-- - Priority 3 only when score 26-50
-- - Priority 4 only when score <= 25
-- =============================================================================

SELECT
    customer_id,
    churn_risk_score,
    intervention_priority,
    'BR004: Priority does not align with score' AS violation
FROM {{ ref('retail_customer_churn_risk') }}
WHERE NOT (
    (intervention_priority = 1 AND churn_risk_score > 75) OR
    (intervention_priority = 2 AND churn_risk_score BETWEEN 51 AND 75) OR
    (intervention_priority = 3 AND churn_risk_score BETWEEN 26 AND 50) OR
    (intervention_priority = 4 AND churn_risk_score <= 25)
)
