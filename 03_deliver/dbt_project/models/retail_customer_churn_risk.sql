{{
  config(
    materialized='table',
    schema='DATA_PRODUCTS',
    tags=['churn_risk', 'retail_banking', 'data_product']
  )
}}

-- ============================================================================
-- Retail Customer Churn Risk Data Product
-- Generated from data contract: retail-customer-churn-risk v1.0.0
-- ============================================================================

WITH customers AS (
    -- Core customer demographics and profile (KYC verified only)
    SELECT
        customer_id,
        customer_name,
        customer_segment,
        region,
        onboarding_date
    FROM {{ source('raw', 'customers') }}
    WHERE kyc_status = 'VERIFIED'
),

accounts AS (
    -- Customer accounts and products (active only)
    SELECT
        account_id,
        customer_id,
        account_type,
        current_balance
    FROM {{ source('raw', 'accounts') }}
    WHERE account_status = 'ACTIVE'
),

transactions AS (
    -- Account transaction history (last 6 months)
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
    -- Mobile app and online banking activity (latest measurement only)
    SELECT
        customer_id,
        login_count_30d,
        mobile_app_active,
        online_banking_active,
        features_used_count,
        measurement_date
    FROM {{ source('raw', 'digital_engagement') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY measurement_date DESC) = 1
),

complaints AS (
    -- Customer complaints (last 12 months)
    SELECT
        complaint_id,
        customer_id,
        status,
        severity,
        complaint_date
    FROM {{ source('raw', 'complaints') }}
    WHERE complaint_date >= DATEADD(month, -12, CURRENT_DATE())
),

-- ============================================================================
-- Aggregations
-- ============================================================================

account_metrics AS (
    SELECT
        customer_id,
        COUNT(DISTINCT account_id) AS total_products_held,
        SUM(current_balance) AS total_relationship_balance,
        MAX(CASE WHEN account_type = 'CURRENT_ACCOUNT' THEN current_balance ELSE 0 END) AS primary_account_balance
    FROM accounts
    GROUP BY customer_id
),

transaction_metrics AS (
    SELECT
        a.customer_id,
        -- Recent 3 months transactions
        COUNT(CASE WHEN t.txn_date >= DATEADD(month, -3, CURRENT_DATE()) THEN 1 END) AS txn_count_recent_3m,
        -- Prior 3 months transactions (3-6 months ago)
        COUNT(CASE WHEN t.txn_date < DATEADD(month, -3, CURRENT_DATE()) THEN 1 END) AS txn_count_prior_3m,
        -- Average monthly transactions (last 3 months)
        ROUND(COUNT(CASE WHEN t.txn_date >= DATEADD(month, -3, CURRENT_DATE()) THEN 1 END) / 3.0, 1) AS avg_monthly_transactions_3m,
        -- Days since last transaction
        DATEDIFF(day, MAX(t.txn_date), CURRENT_DATE()) AS days_since_last_transaction
    FROM accounts a
    LEFT JOIN transactions t ON a.account_id = t.account_id
    GROUP BY a.customer_id
),

complaint_metrics AS (
    SELECT
        customer_id,
        COUNT(*) AS complaints_last_12m,
        COUNT(CASE WHEN status = 'OPEN' THEN 1 END) AS open_complaints_count
    FROM complaints
    GROUP BY customer_id
),

-- ============================================================================
-- Risk Calculations
-- ============================================================================

base_metrics AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        c.region,
        
        -- Relationship tenure
        DATEDIFF(month, c.onboarding_date, CURRENT_DATE()) AS relationship_tenure_months,
        
        -- Account metrics
        COALESCE(am.total_products_held, 0) AS total_products_held,
        COALESCE(am.primary_account_balance, 0) AS primary_account_balance,
        COALESCE(am.total_relationship_balance, 0) AS total_relationship_balance,
        
        -- Transaction metrics
        COALESCE(tm.avg_monthly_transactions_3m, 0) AS avg_monthly_transactions_3m,
        COALESCE(tm.txn_count_recent_3m, 0) AS txn_count_recent_3m,
        COALESCE(tm.txn_count_prior_3m, 0) AS txn_count_prior_3m,
        COALESCE(tm.days_since_last_transaction, 999) AS days_since_last_transaction,
        
        -- Digital engagement
        COALESCE(de.mobile_app_active, FALSE) AS mobile_app_active,
        COALESCE(de.login_count_30d, 0) AS login_count_30d,
        COALESCE(de.online_banking_active, FALSE) AS online_banking_active,
        COALESCE(de.features_used_count, 0) AS features_used_count,
        
        -- Complaints
        COALESCE(cm.complaints_last_12m, 0) AS complaints_last_12m,
        COALESCE(cm.open_complaints_count, 0) AS open_complaints_count
        
    FROM customers c
    LEFT JOIN account_metrics am ON c.customer_id = am.customer_id
    LEFT JOIN transaction_metrics tm ON c.customer_id = tm.customer_id
    LEFT JOIN digital_engagement de ON c.customer_id = de.customer_id
    LEFT JOIN complaint_metrics cm ON c.customer_id = cm.customer_id
),

derived_metrics AS (
    SELECT
        *,
        
        -- Transaction trend
        CASE
            WHEN txn_count_prior_3m = 0 THEN 'STABLE'
            WHEN txn_count_recent_3m > txn_count_prior_3m * 1.1 THEN 'INCREASING'
            WHEN txn_count_recent_3m >= txn_count_prior_3m * 0.9 THEN 'STABLE'
            WHEN txn_count_recent_3m >= txn_count_prior_3m * 0.5 THEN 'DECLINING'
            ELSE 'SEVERELY_DECLINING'
        END AS transaction_trend,
        
        -- Balance trend (simplified - production would use historical snapshots)
        CASE
            WHEN total_relationship_balance > 1000 THEN 'STABLE'
            ELSE 'DECLINING'
        END AS balance_trend,
        
        -- Digital engagement score (0-100)
        LEAST(100, 
            (login_count_30d * 2) + 
            (CASE WHEN mobile_app_active THEN 20 ELSE 0 END) +
            (CASE WHEN online_banking_active THEN 10 ELSE 0 END) +
            (features_used_count * 2)
        ) AS digital_engagement_score,
        
        -- Has unresolved complaint
        (open_complaints_count > 0) AS has_unresolved_complaint,
        
        -- Risk driver flags
        (total_relationship_balance < 500 OR primary_account_balance < 100) AS declining_balance_flag,
        
        (txn_count_prior_3m > 0 AND txn_count_recent_3m < txn_count_prior_3m * 0.7) AS reduced_activity_flag,
        
        (login_count_30d < 3 AND NOT mobile_app_active) AS low_engagement_flag,
        
        (open_complaints_count > 0 OR complaints_last_12m >= 2) AS complaint_flag,
        
        (days_since_last_transaction > 45) AS dormancy_flag
        
    FROM base_metrics
),

risk_scores AS (
    SELECT
        *,
        
        -- Calculate churn risk score
        LEAST(100, GREATEST(0,
            20  -- Base score
            + (CASE WHEN declining_balance_flag THEN 20 ELSE 0 END)
            + (CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END)
            + (CASE WHEN low_engagement_flag THEN 15 ELSE 0 END)
            + (CASE WHEN complaint_flag THEN 15 ELSE 0 END)
            + (CASE WHEN dormancy_flag THEN 25 ELSE 0 END)
            - (CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END)
            - (CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END)
            - (CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END)
            + (CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 ELSE 0 END)
            - (CASE WHEN customer_segment = 'HIGH_NET_WORTH' THEN 5 ELSE 0 END)
        )) AS churn_risk_score
        
    FROM derived_metrics
)

-- ============================================================================
-- Final Output
-- ============================================================================

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
    
    -- Digital Engagement
    mobile_app_active,
    login_count_30d,
    digital_engagement_score,
    
    -- Complaints
    open_complaints_count,
    complaints_last_12m,
    has_unresolved_complaint,
    
    -- Churn Risk Outputs
    churn_risk_score,
    
    CASE
        WHEN churn_risk_score <= 25 THEN 'LOW'
        WHEN churn_risk_score <= 50 THEN 'MEDIUM'
        WHEN churn_risk_score <= 75 THEN 'HIGH'
        ELSE 'CRITICAL'
    END AS risk_tier,
    
    -- Risk Driver Flags
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    
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
    )::STRING AS risk_drivers_json,
    
    -- Recommended Actions
    CASE
        WHEN churn_risk_score > 75 THEN 'URGENT_ESCALATION'
        WHEN churn_risk_score > 50 AND complaint_flag THEN 'RELATIONSHIP_CALL'
        WHEN churn_risk_score > 50 THEN 'RETENTION_OFFER'
        WHEN churn_risk_score > 25 AND low_engagement_flag THEN 'DIGITAL_ENGAGEMENT'
        WHEN churn_risk_score > 25 THEN 'BRANCH_MEETING'
        ELSE 'NO_ACTION'
    END AS recommended_intervention,
    
    CASE
        WHEN churn_risk_score > 75 THEN 1
        WHEN churn_risk_score > 50 THEN 2
        WHEN churn_risk_score > 25 THEN 3
        ELSE 4
    END AS intervention_priority,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS score_calculated_at,
    CURRENT_DATE() AS data_as_of_date,
    '1.0.0' AS model_version

FROM risk_scores
