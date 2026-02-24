{{
  config(
    materialized='table',
    tags=['churn', 'risk', 'retention', 'customer-analytics', 'PO123'],
    meta={
      'owner': 'Alex Morgan',
      'contract_version': '1.0.0',
      'description': 'Retail Customer Churn Risk data product'
    }
  )
}}

/*
==============================================================================
DATA PRODUCT: Retail Customer Churn Risk
==============================================================================
Generated from: 02_design/retail_churn_contract.yaml
Owner: Alex Morgan
Version: 1.0.0

Business Goal: Reduce customer churn from 8.5% to 6.0%
==============================================================================
*/

-- =============================================================================
-- SOURCE CTEs
-- =============================================================================

WITH customers AS (
    SELECT
        customer_id,
        customer_name,
        customer_segment,
        region,
        onboarding_date,
        kyc_status
    FROM {{ source('raw', 'customers') }}
    WHERE kyc_status = 'VERIFIED'
),

accounts AS (
    SELECT
        account_id,
        customer_id,
        account_type,
        account_status,
        current_balance,
        opened_date
    FROM {{ source('raw', 'accounts') }}
    WHERE account_status = 'ACTIVE'
),

transactions AS (
    SELECT
        txn_id,
        account_id,
        txn_date,
        amount,
        channel
    FROM {{ source('raw', 'transactions') }}
    WHERE txn_date >= DATEADD(month, -6, CURRENT_DATE())
),

digital_engagement AS (
    SELECT
        customer_id,
        login_count_30d,
        mobile_app_active,
        online_banking_active,
        features_used_count,
        measurement_date
    FROM {{ source('raw', 'digital_engagement') }}
    -- Get latest measurement per customer
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY measurement_date DESC) = 1
),

complaints AS (
    SELECT
        complaint_id,
        customer_id,
        complaint_date,
        status,
        severity,
        resolution_date
    FROM {{ source('raw', 'complaints') }}
    WHERE complaint_date >= DATEADD(month, -12, CURRENT_DATE())
),

-- =============================================================================
-- AGGREGATION CTEs
-- =============================================================================

-- Account aggregations per customer
account_metrics AS (
    SELECT
        customer_id,
        COUNT(DISTINCT account_id) AS total_products_held,
        MAX(CASE WHEN account_type = 'CURRENT_ACCOUNT' THEN current_balance ELSE 0 END) AS primary_account_balance,
        SUM(current_balance) AS total_relationship_balance
    FROM accounts
    GROUP BY customer_id
),

-- Transaction aggregations per customer (via accounts)
transaction_metrics AS (
    SELECT
        a.customer_id,
        -- Recent 3 months
        COUNT(CASE WHEN t.txn_date >= DATEADD(month, -3, CURRENT_DATE()) THEN 1 END) AS txn_count_recent_3m,
        -- Prior 3 months (months 4-6)
        COUNT(CASE WHEN t.txn_date >= DATEADD(month, -6, CURRENT_DATE()) 
                    AND t.txn_date < DATEADD(month, -3, CURRENT_DATE()) THEN 1 END) AS txn_count_prior_3m,
        -- Last transaction date
        MAX(t.txn_date) AS last_transaction_date
    FROM accounts a
    LEFT JOIN transactions t ON a.account_id = t.account_id
    GROUP BY a.customer_id
),

-- Complaint aggregations per customer
complaint_metrics AS (
    SELECT
        customer_id,
        COUNT(CASE WHEN status = 'OPEN' THEN 1 END) AS open_complaints_count,
        COUNT(*) AS complaints_last_12m
    FROM complaints
    GROUP BY customer_id
),

-- =============================================================================
-- INTERMEDIATE CALCULATIONS
-- =============================================================================

intermediate AS (
    SELECT
        -- Customer Identifiers
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        c.region,
        
        -- Relationship Attributes
        DATEDIFF(month, c.onboarding_date, CURRENT_DATE()) AS relationship_tenure_months,
        COALESCE(am.total_products_held, 0) AS total_products_held,
        COALESCE(am.primary_account_balance, 0) AS primary_account_balance,
        COALESCE(am.total_relationship_balance, 0) AS total_relationship_balance,
        
        -- Behavioral Signals
        ROUND(COALESCE(tm.txn_count_recent_3m, 0) / 3.0, 1) AS avg_monthly_transactions_3m,
        tm.txn_count_recent_3m,
        tm.txn_count_prior_3m,
        CASE
            WHEN COALESCE(tm.txn_count_prior_3m, 0) = 0 THEN 'STABLE'
            WHEN tm.txn_count_recent_3m > tm.txn_count_prior_3m * 1.1 THEN 'INCREASING'
            WHEN tm.txn_count_recent_3m >= tm.txn_count_prior_3m * 0.9 THEN 'STABLE'
            WHEN tm.txn_count_recent_3m >= tm.txn_count_prior_3m * 0.5 THEN 'DECLINING'
            ELSE 'SEVERELY_DECLINING'
        END AS transaction_trend,
        CASE
            WHEN COALESCE(am.total_relationship_balance, 0) > 1000 THEN 'STABLE'
            ELSE 'DECLINING'
        END AS balance_trend,
        COALESCE(DATEDIFF(day, tm.last_transaction_date, CURRENT_DATE()), 999) AS days_since_last_transaction,
        
        -- Digital Engagement Signals
        COALESCE(de.mobile_app_active, FALSE) AS mobile_app_active,
        COALESCE(de.login_count_30d, 0) AS login_count_30d,
        LEAST(100, 
            COALESCE(de.login_count_30d, 0) * 2 +
            CASE WHEN de.mobile_app_active THEN 20 ELSE 0 END +
            CASE WHEN de.online_banking_active THEN 10 ELSE 0 END +
            COALESCE(de.features_used_count, 0) * 2
        ) AS digital_engagement_score,
        
        -- Complaint Signals
        COALESCE(cm.open_complaints_count, 0) AS open_complaints_count,
        COALESCE(cm.complaints_last_12m, 0) AS complaints_last_12m
        
    FROM customers c
    LEFT JOIN account_metrics am ON c.customer_id = am.customer_id
    LEFT JOIN transaction_metrics tm ON c.customer_id = tm.customer_id
    LEFT JOIN digital_engagement de ON c.customer_id = de.customer_id
    LEFT JOIN complaint_metrics cm ON c.customer_id = cm.customer_id
),

-- =============================================================================
-- RISK FLAG CALCULATIONS
-- =============================================================================

with_risk_flags AS (
    SELECT
        *,
        -- Has unresolved complaint
        (open_complaints_count > 0) AS has_unresolved_complaint,
        
        -- Risk Driver Flags
        (total_relationship_balance < 500 OR primary_account_balance < 100) AS declining_balance_flag,
        (transaction_trend IN ('DECLINING', 'SEVERELY_DECLINING')) AS reduced_activity_flag,
        (login_count_30d < 3 AND mobile_app_active = FALSE) AS low_engagement_flag,
        (open_complaints_count > 0 OR complaints_last_12m >= 2) AS complaint_flag,
        (days_since_last_transaction > 45) AS dormancy_flag
    FROM intermediate
),

-- =============================================================================
-- CHURN RISK SCORE CALCULATION
-- =============================================================================

with_churn_score AS (
    SELECT
        *,
        -- Base score + risk factors - protective factors
        GREATEST(0, LEAST(100,
            20  -- Base score
            + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
            + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
            + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
            + CASE WHEN complaint_flag THEN 15 ELSE 0 END
            + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
            - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
            - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
            - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
            + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 ELSE 0 END
            - CASE WHEN customer_segment = 'HIGH_NET_WORTH' THEN 5 ELSE 0 END
        )) AS churn_risk_score
    FROM with_risk_flags
),

-- =============================================================================
-- FINAL OUTPUT
-- =============================================================================

final AS (
    SELECT
        -- Customer Identifiers
        customer_id,
        customer_name,
        customer_segment,
        region,
        
        -- Relationship Attributes
        relationship_tenure_months,
        total_products_held,
        primary_account_balance,
        total_relationship_balance,
        
        -- Behavioral Signals
        avg_monthly_transactions_3m,
        transaction_trend,
        balance_trend,
        days_since_last_transaction,
        
        -- Digital Engagement Signals
        mobile_app_active,
        login_count_30d,
        digital_engagement_score,
        
        -- Complaint Signals
        open_complaints_count,
        complaints_last_12m,
        has_unresolved_complaint,
        
        -- Risk Driver Flags
        declining_balance_flag,
        reduced_activity_flag,
        low_engagement_flag,
        complaint_flag,
        dormancy_flag,
        
        -- Churn Risk Outputs
        churn_risk_score,
        
        -- Risk Tier
        CASE
            WHEN churn_risk_score <= 25 THEN 'LOW'
            WHEN churn_risk_score <= 50 THEN 'MEDIUM'
            WHEN churn_risk_score <= 75 THEN 'HIGH'
            ELSE 'CRITICAL'
        END AS risk_tier,
        
        -- Primary Risk Driver
        CASE
            WHEN dormancy_flag AND days_since_last_transaction > 60 THEN 'DORMANCY'
            WHEN declining_balance_flag AND primary_account_balance < 100 THEN 'BALANCE_DECLINE'
            WHEN reduced_activity_flag THEN 'ACTIVITY_REDUCTION'
            WHEN complaint_flag AND open_complaints_count > 0 THEN 'COMPLAINTS'
            WHEN low_engagement_flag THEN 'LOW_ENGAGEMENT'
            WHEN churn_risk_score > 50 THEN 'MULTI_FACTOR'
            ELSE 'NONE'
        END AS primary_risk_driver,
        
        -- Risk Drivers JSON
        OBJECT_CONSTRUCT(
            'declining_balance', OBJECT_CONSTRUCT('flag', declining_balance_flag, 'balance', total_relationship_balance),
            'reduced_activity', OBJECT_CONSTRUCT('flag', reduced_activity_flag, 'trend', transaction_trend),
            'low_engagement', OBJECT_CONSTRUCT('flag', low_engagement_flag, 'score', digital_engagement_score),
            'complaints', OBJECT_CONSTRUCT('flag', complaint_flag, 'open_count', open_complaints_count, 'total_12m', complaints_last_12m),
            'dormancy', OBJECT_CONSTRUCT('flag', dormancy_flag, 'days_inactive', days_since_last_transaction)
        )::VARCHAR AS risk_drivers_json,
        
        -- Recommended Intervention
        CASE
            WHEN churn_risk_score > 75 THEN 'URGENT_ESCALATION'
            WHEN churn_risk_score > 50 AND complaint_flag THEN 'RELATIONSHIP_CALL'
            WHEN churn_risk_score > 50 THEN 'RETENTION_OFFER'
            WHEN churn_risk_score > 25 AND low_engagement_flag THEN 'DIGITAL_ENGAGEMENT'
            WHEN churn_risk_score > 25 THEN 'BRANCH_MEETING'
            ELSE 'NO_ACTION'
        END AS recommended_intervention,
        
        -- Intervention Priority
        CASE
            WHEN churn_risk_score > 75 THEN 1
            WHEN churn_risk_score > 50 THEN 2
            WHEN churn_risk_score > 25 THEN 3
            ELSE 4
        END AS intervention_priority,
        
        -- Metadata & Audit
        CURRENT_TIMESTAMP() AS score_calculated_at,
        CURRENT_DATE() AS data_as_of_date,
        '1.0.0' AS model_version
        
    FROM with_churn_score
)

SELECT * FROM final
