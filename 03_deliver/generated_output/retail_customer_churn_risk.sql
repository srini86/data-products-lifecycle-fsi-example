-- ============================================================================
-- DBT MODEL: Retail Customer Churn Risk
-- ============================================================================
-- Generated from: Data Contract (02_design/churn_risk_data_contract.yaml)
-- Contract Version: 1.0.0
-- 
-- This model implements all derivation logic from the data contract to produce
-- a unified churn risk data product for retail banking customers.
-- ============================================================================

{{
  config(
    materialized='table',
    unique_key='customer_id'
  )
}}

-- ============================================================================
-- SOURCE CTEs
-- ============================================================================

WITH customers AS (
    -- Core customer demographics and profile
    -- Filter: kyc_status = 'VERIFIED'
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
    -- Customer accounts and products
    -- Filter: account_status = 'ACTIVE'
    SELECT 
        customer_id,
        account_id,
        account_type,
        current_balance
    FROM {{ source('raw', 'accounts') }}
    WHERE account_status = 'ACTIVE'
),

transactions_last_6m AS (
    -- Account transaction history
    -- Filter: Last 6 months of transactions
    SELECT 
        t.account_id,
        t.txn_id,
        t.txn_date,
        t.amount,
        t.channel,
        a.customer_id
    FROM {{ source('raw', 'transactions') }} t
    INNER JOIN accounts a ON t.account_id = a.account_id
    WHERE t.txn_date >= DATEADD(month, -6, CURRENT_DATE())
),

digital_engagement AS (
    -- Mobile app and online banking activity
    -- Filter: Latest measurement date only
    SELECT 
        customer_id,
        login_count_30d,
        mobile_app_active,
        online_banking_active,
        features_used_count
    FROM {{ source('raw', 'digital_engagement') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY measurement_date DESC) = 1
),

complaints AS (
    -- Customer complaints and service issues
    -- Filter: Last 12 months of complaints
    SELECT 
        customer_id,
        complaint_id,
        status,
        severity
    FROM {{ source('raw', 'complaints') }}
    WHERE complaint_date >= DATEADD(month, -12, CURRENT_DATE())
),

-- ============================================================================
-- AGGREGATION CTEs
-- ============================================================================

customer_account_metrics AS (
    -- Calculate relationship tenure and account metrics per customer
    SELECT
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        c.region,
        c.onboarding_date,
        -- Relationship tenure: months since onboarding
        DATEDIFF(month, c.onboarding_date, CURRENT_DATE()) AS relationship_tenure_months,
        -- Total products held: count of active accounts
        COUNT(DISTINCT a.account_id) AS total_products_held,
        -- Primary account balance: max balance from CURRENT_ACCOUNT
        COALESCE(MAX(CASE WHEN a.account_type = 'CURRENT_ACCOUNT' THEN a.current_balance END), 0) AS primary_account_balance,
        -- Total relationship balance: sum of all account balances
        COALESCE(SUM(a.current_balance), 0) AS total_relationship_balance
    FROM customers c
    LEFT JOIN accounts a ON c.customer_id = a.customer_id
    GROUP BY c.customer_id, c.customer_name, c.customer_segment, c.region, c.onboarding_date
),

transaction_metrics AS (
    -- Calculate transaction-based metrics
    SELECT
        customer_id,
        -- Average monthly transactions (last 3 months)
        ROUND(COUNT(CASE WHEN txn_date >= DATEADD(month, -3, CURRENT_DATE()) THEN txn_id END) / 3.0, 1) AS avg_monthly_transactions_3m,
        -- Days since last transaction
        COALESCE(DATEDIFF(day, MAX(txn_date), CURRENT_DATE()), 999) AS days_since_last_transaction,
        -- Transaction counts for trend calculation
        COUNT(CASE WHEN txn_date >= DATEADD(month, -3, CURRENT_DATE()) THEN txn_id END) AS recent_3m_txns,
        COUNT(CASE WHEN txn_date BETWEEN DATEADD(month, -6, CURRENT_DATE()) AND DATEADD(month, -3, CURRENT_DATE()) THEN txn_id END) AS prior_3m_txns
    FROM transactions_last_6m
    GROUP BY customer_id
),

transaction_trends AS (
    -- Derive transaction trend based on volume comparison
    SELECT
        customer_id,
        avg_monthly_transactions_3m,
        days_since_last_transaction,
        recent_3m_txns,
        prior_3m_txns,
        CASE
            WHEN prior_3m_txns = 0 AND recent_3m_txns > 0 THEN 'INCREASING'
            WHEN prior_3m_txns = 0 AND recent_3m_txns = 0 THEN 'STABLE'
            WHEN recent_3m_txns > prior_3m_txns * 1.1 THEN 'INCREASING'
            WHEN recent_3m_txns >= prior_3m_txns * 0.9 THEN 'STABLE'
            WHEN recent_3m_txns >= prior_3m_txns * 0.5 THEN 'DECLINING'
            ELSE 'SEVERELY_DECLINING'
        END AS transaction_trend
    FROM transaction_metrics
),

complaint_metrics AS (
    -- Calculate complaint-based metrics
    SELECT
        customer_id,
        -- Open complaints count
        COUNT(CASE WHEN status = 'OPEN' THEN complaint_id END) AS open_complaints_count,
        -- Total complaints in last 12 months
        COUNT(complaint_id) AS complaints_last_12m
    FROM complaints
    GROUP BY customer_id
),

-- ============================================================================
-- COMBINED METRICS WITH RISK FLAGS
-- ============================================================================

combined_metrics AS (
    SELECT
        cam.customer_id,
        cam.customer_name,
        cam.customer_segment,
        cam.region,
        cam.relationship_tenure_months,
        cam.total_products_held,
        cam.primary_account_balance,
        cam.total_relationship_balance,
        
        -- Transaction metrics
        COALESCE(tt.avg_monthly_transactions_3m, 0) AS avg_monthly_transactions_3m,
        COALESCE(tt.transaction_trend, 'STABLE') AS transaction_trend,
        COALESCE(tt.days_since_last_transaction, 999) AS days_since_last_transaction,
        COALESCE(tt.recent_3m_txns, 0) AS recent_3m_txns,
        COALESCE(tt.prior_3m_txns, 0) AS prior_3m_txns,
        
        -- Balance trend (simplified: based on current balance level)
        CASE 
            WHEN cam.total_relationship_balance > 1000 THEN 'STABLE' 
            ELSE 'DECLINING' 
        END AS balance_trend,
        
        -- Digital engagement metrics
        COALESCE(de.mobile_app_active, FALSE) AS mobile_app_active,
        COALESCE(de.login_count_30d, 0) AS login_count_30d,
        COALESCE(de.features_used_count, 0) AS features_used_count,
        COALESCE(de.online_banking_active, FALSE) AS online_banking_active,
        
        -- Digital engagement score calculation
        -- login_count_30d * 2 + mobile_active(+20) + online_active(+10) + features * 2, capped at 100
        LEAST(100, 
            COALESCE(de.login_count_30d, 0) * 2 +
            CASE WHEN COALESCE(de.mobile_app_active, FALSE) THEN 20 ELSE 0 END +
            CASE WHEN COALESCE(de.online_banking_active, FALSE) THEN 10 ELSE 0 END +
            COALESCE(de.features_used_count, 0) * 2
        ) AS digital_engagement_score,
        
        -- Complaint metrics
        COALESCE(cm.open_complaints_count, 0) AS open_complaints_count,
        COALESCE(cm.complaints_last_12m, 0) AS complaints_last_12m,
        
        -- Risk flags
        -- Declining balance flag: balance < 500 OR primary < 100
        (cam.total_relationship_balance < 500 OR cam.primary_account_balance < 100) AS declining_balance_flag,
        
        -- Reduced activity flag: recent 3m < 70% of prior 3m
        (COALESCE(tt.prior_3m_txns, 0) > 0 AND COALESCE(tt.recent_3m_txns, 0) < COALESCE(tt.prior_3m_txns, 0) * 0.7) AS reduced_activity_flag,
        
        -- Low engagement flag: login_count < 3 AND mobile_app_active = false
        (COALESCE(de.login_count_30d, 0) < 3 AND COALESCE(de.mobile_app_active, FALSE) = FALSE) AS low_engagement_flag,
        
        -- Complaint flag: open > 0 OR total_12m >= 2
        (COALESCE(cm.open_complaints_count, 0) > 0 OR COALESCE(cm.complaints_last_12m, 0) >= 2) AS complaint_flag,
        
        -- Dormancy flag: days since last transaction > 45
        (COALESCE(tt.days_since_last_transaction, 999) > 45) AS dormancy_flag
        
    FROM customer_account_metrics cam
    LEFT JOIN transaction_trends tt ON cam.customer_id = tt.customer_id
    LEFT JOIN digital_engagement de ON cam.customer_id = de.customer_id
    LEFT JOIN complaint_metrics cm ON cam.customer_id = cm.customer_id
),

-- ============================================================================
-- FINAL OUTPUT WITH RISK SCORES AND RECOMMENDATIONS
-- ============================================================================

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
        
        -- Complaint & Service Signals
        open_complaints_count,
        complaints_last_12m,
        (open_complaints_count > 0) AS has_unresolved_complaint,
        
        -- Risk Driver Flags
        declining_balance_flag,
        reduced_activity_flag,
        low_engagement_flag,
        complaint_flag,
        dormancy_flag,
        
        -- Churn Risk Score Calculation (0-100)
        -- Base: 20, Risk factors add, Protective factors subtract, Segment adjustment
        LEAST(100, GREATEST(0,
            20  -- Base score
            + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
            + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
            + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
            + CASE WHEN complaint_flag THEN 15 ELSE 0 END
            + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
            - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END  -- Multi-product customer
            - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END  -- Long tenure
            - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END  -- Highly engaged
            + CASE 
                WHEN customer_segment = 'MASS_MARKET' THEN 5
                WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5
                ELSE 0 
              END
        )) AS churn_risk_score,
        
        -- Risk Tier Classification
        CASE 
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) <= 25 THEN 'LOW'
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) <= 50 THEN 'MEDIUM'
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) <= 75 THEN 'HIGH'
            ELSE 'CRITICAL'
        END AS risk_tier,
        
        -- Primary Risk Driver (by priority)
        CASE
            WHEN dormancy_flag AND days_since_last_transaction > 60 THEN 'DORMANCY'
            WHEN declining_balance_flag AND primary_account_balance < 100 THEN 'BALANCE_DECLINE'
            WHEN reduced_activity_flag THEN 'ACTIVITY_REDUCTION'
            WHEN complaint_flag AND open_complaints_count > 0 THEN 'COMPLAINTS'
            WHEN low_engagement_flag THEN 'LOW_ENGAGEMENT'
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 50 THEN 'MULTI_FACTOR'
            ELSE 'NONE'
        END AS primary_risk_driver,
        
        -- Risk Drivers JSON (detailed breakdown)
        OBJECT_CONSTRUCT(
            'declining_balance', OBJECT_CONSTRUCT('flag', declining_balance_flag, 'balance', total_relationship_balance),
            'reduced_activity', OBJECT_CONSTRUCT('flag', reduced_activity_flag, 'trend', transaction_trend),
            'low_engagement', OBJECT_CONSTRUCT('flag', low_engagement_flag, 'score', digital_engagement_score),
            'complaints', OBJECT_CONSTRUCT('flag', complaint_flag, 'open_count', open_complaints_count, 'total_12m', complaints_last_12m),
            'dormancy', OBJECT_CONSTRUCT('flag', dormancy_flag, 'days_inactive', days_since_last_transaction)
        )::STRING AS risk_drivers_json,
        
        -- Recommended Intervention
        CASE
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 75 THEN 'URGENT_ESCALATION'
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 50 AND complaint_flag THEN 'RELATIONSHIP_CALL'
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 50 THEN 'RETENTION_OFFER'
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 25 AND low_engagement_flag THEN 'DIGITAL_ENGAGEMENT'
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 25 THEN 'BRANCH_MEETING'
            ELSE 'NO_ACTION'
        END AS recommended_intervention,
        
        -- Intervention Priority (1=highest)
        CASE
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 75 THEN 1
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 50 THEN 2
            WHEN LEAST(100, GREATEST(0,
                20 + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
                + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
                + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
                + CASE WHEN complaint_flag THEN 15 ELSE 0 END
                + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
                - CASE WHEN total_products_held >= 3 THEN 10 ELSE 0 END
                - CASE WHEN relationship_tenure_months > 60 THEN 10 ELSE 0 END
                - CASE WHEN digital_engagement_score > 70 THEN 10 ELSE 0 END
                + CASE WHEN customer_segment = 'MASS_MARKET' THEN 5 WHEN customer_segment = 'HIGH_NET_WORTH' THEN -5 ELSE 0 END
            )) > 25 THEN 3
            ELSE 4
        END AS intervention_priority,
        
        -- Metadata & Audit
        CURRENT_TIMESTAMP() AS score_calculated_at,
        CURRENT_DATE() AS data_as_of_date,
        '1.0.0' AS model_version
        
    FROM combined_metrics
)

SELECT * FROM final
