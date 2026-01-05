{{
    config(
        materialized='table',
        tags=['data_product', 'retail_banking', 'churn_risk'],
        unique_key='customer_id',
        post_hook=[
            "CREATE TAG IF NOT EXISTS pii",
            "CREATE TAG IF NOT EXISTS financial",
            "CREATE TAG IF NOT EXISTS risk_score",
            "ALTER TABLE {{ this }} MODIFY COLUMN customer_name SET TAG pii = 'true'",
            "ALTER TABLE {{ this }} MODIFY COLUMN churn_risk_score SET TAG risk_score = 'true'",
            "ALTER TABLE {{ this }} MODIFY COLUMN primary_account_balance SET TAG financial = 'true'",
            "ALTER TABLE {{ this }} MODIFY COLUMN total_relationship_balance SET TAG financial = 'true'"
        ]
    )
}}

/*
============================================================================
DATA PRODUCT: Retail Customer Churn Risk
============================================================================
CONTRACT VERSION: 1.0.0
OWNER: alex.morgan@bank.com

DESCRIPTION:
A governed, daily-refreshed data product providing unified churn risk 
scores for retail banking customers. Combines behavioral signals, 
transactional patterns, and engagement data to produce explainable 
risk scores that power retention campaigns and branch interventions.

GRAIN: One row per retail customer
PRIMARY KEY: customer_id

SOURCE TABLES:
- {{ source('raw', 'customers') }}
- {{ source('raw', 'accounts') }}
- {{ source('raw', 'transactions') }}
- {{ source('raw', 'digital_engagement') }}
- {{ source('raw', 'complaints') }}

BUSINESS RULES:
- Risk score: 0-100 (higher = more risk)
- Risk tiers: LOW (0-25), MEDIUM (26-50), HIGH (51-75), CRITICAL (76-100)
- At least one risk driver must be flagged for HIGH/CRITICAL
- Urgent escalation only for CRITICAL tier

SLA:
- Refresh: Daily by 6 AM UTC
- Availability: 99.5%
============================================================================
*/

-- ============================================================================
-- SOURCE CTEs: Extract and filter source data
-- ============================================================================

WITH customers AS (
    -- Core customer demographics
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
    -- Active customer accounts
    SELECT 
        account_id,
        customer_id,
        account_type,
        product_name,
        current_balance,
        opened_date
    FROM {{ source('raw', 'accounts') }}
    WHERE account_status = 'ACTIVE'
),

transactions AS (
    -- Last 6 months of transaction data
    SELECT 
        txn_id,
        account_id,
        txn_date,
        txn_type,
        amount,
        channel
    FROM {{ source('raw', 'transactions') }}
    WHERE txn_date >= DATEADD('month', -6, CURRENT_DATE())
),

digital_engagement AS (
    -- Latest digital engagement snapshot
    SELECT 
        customer_id,
        login_count_30d,
        mobile_app_active,
        online_banking_active,
        last_login_date,
        session_count_30d,
        features_used_count,
        push_notifications_enabled
    FROM {{ source('raw', 'digital_engagement') }}
    WHERE measurement_date = (
        SELECT MAX(measurement_date) 
        FROM {{ source('raw', 'digital_engagement') }}
    )
),

complaints AS (
    -- Last 12 months of complaints
    SELECT 
        complaint_id,
        customer_id,
        complaint_date,
        category,
        severity,
        status,
        resolution_date,
        escalated
    FROM {{ source('raw', 'complaints') }}
    WHERE complaint_date >= DATEADD('month', -12, CURRENT_DATE())
),

-- ============================================================================
-- AGGREGATION CTEs: Build customer-level metrics
-- ============================================================================

-- Account portfolio metrics
account_metrics AS (
    SELECT
        customer_id,
        COUNT(DISTINCT account_id) AS total_products_held,
        SUM(current_balance) AS total_relationship_balance,
        -- Primary account = current account with highest balance
        MAX(CASE 
            WHEN account_type = 'CURRENT_ACCOUNT' THEN current_balance 
            ELSE 0 
        END) AS primary_account_balance,
        -- Product diversity
        COUNT(DISTINCT account_type) AS product_type_count,
        MIN(opened_date) AS first_account_date
    FROM accounts
    GROUP BY customer_id
),

-- Transaction behavior analysis
transaction_metrics AS (
    SELECT
        a.customer_id,
        
        -- Recent period (last 3 months)
        COUNT(CASE 
            WHEN t.txn_date >= DATEADD('month', -3, CURRENT_DATE()) 
            THEN 1 
        END) AS txn_count_recent_3m,
        
        COALESCE(SUM(CASE 
            WHEN t.txn_date >= DATEADD('month', -3, CURRENT_DATE()) 
            THEN ABS(t.amount) 
        END), 0) AS txn_volume_recent_3m,
        
        -- Prior period (3-6 months ago)
        COUNT(CASE 
            WHEN t.txn_date < DATEADD('month', -3, CURRENT_DATE()) 
            THEN 1 
        END) AS txn_count_prior_3m,
        
        COALESCE(SUM(CASE 
            WHEN t.txn_date < DATEADD('month', -3, CURRENT_DATE()) 
            THEN ABS(t.amount) 
        END), 0) AS txn_volume_prior_3m,
        
        -- Activity recency
        MAX(t.txn_date) AS last_transaction_date,
        DATEDIFF('day', MAX(t.txn_date), CURRENT_DATE()) AS days_since_last_txn,
        
        -- Channel diversity
        COUNT(DISTINCT t.channel) AS channels_used
        
    FROM accounts a
    LEFT JOIN transactions t ON a.account_id = t.account_id
    GROUP BY a.customer_id
),

-- Digital engagement scoring
engagement_metrics AS (
    SELECT
        customer_id,
        login_count_30d,
        mobile_app_active,
        online_banking_active,
        last_login_date,
        DATEDIFF('day', last_login_date, CURRENT_DATE()) AS days_since_last_login,
        session_count_30d,
        features_used_count,
        push_notifications_enabled,
        
        -- Composite engagement score (0-100)
        LEAST(100, 
            COALESCE(login_count_30d, 0) * 2 +                           -- Login frequency (max 60 pts)
            CASE WHEN mobile_app_active THEN 20 ELSE 0 END +             -- Mobile active (20 pts)
            CASE WHEN online_banking_active THEN 10 ELSE 0 END +         -- Online active (10 pts)
            COALESCE(features_used_count, 0) * 2                         -- Feature adoption (max 24 pts)
        ) AS digital_engagement_score
        
    FROM digital_engagement
),

-- Complaint analysis
complaint_metrics AS (
    SELECT
        customer_id,
        COUNT(*) AS complaints_last_12m,
        SUM(CASE WHEN status = 'OPEN' THEN 1 ELSE 0 END) AS open_complaints_count,
        SUM(CASE WHEN severity IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS severe_complaints_count,
        SUM(CASE WHEN escalated THEN 1 ELSE 0 END) AS escalated_complaints_count,
        MAX(CASE WHEN status = 'OPEN' THEN 1 ELSE 0 END) = 1 AS has_unresolved_complaint,
        MAX(complaint_date) AS last_complaint_date
    FROM complaints
    GROUP BY customer_id
),

-- ============================================================================
-- RISK CALCULATION: Combine signals into risk indicators
-- ============================================================================

risk_signals AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.customer_segment,
        c.region,
        
        -- Relationship tenure
        DATEDIFF('month', c.onboarding_date, CURRENT_DATE()) AS relationship_tenure_months,
        
        -- Account metrics
        COALESCE(am.total_products_held, 0) AS total_products_held,
        COALESCE(am.primary_account_balance, 0) AS primary_account_balance,
        COALESCE(am.total_relationship_balance, 0) AS total_relationship_balance,
        
        -- Transaction metrics
        ROUND(COALESCE(tm.txn_count_recent_3m, 0) / 3.0, 1) AS avg_monthly_transactions_3m,
        COALESCE(tm.days_since_last_txn, 999) AS days_since_last_transaction,
        
        -- Transaction trend classification
        CASE
            WHEN COALESCE(tm.txn_count_prior_3m, 0) = 0 THEN 'STABLE'
            WHEN tm.txn_count_recent_3m > tm.txn_count_prior_3m * 1.1 THEN 'INCREASING'
            WHEN tm.txn_count_recent_3m >= tm.txn_count_prior_3m * 0.9 THEN 'STABLE'
            WHEN tm.txn_count_recent_3m >= tm.txn_count_prior_3m * 0.5 THEN 'DECLINING'
            ELSE 'SEVERELY_DECLINING'
        END AS transaction_trend,
        
        -- Balance trend (simplified - in production would use historical snapshots)
        CASE
            WHEN am.total_relationship_balance > 10000 THEN 'STABLE'
            WHEN am.total_relationship_balance > 1000 THEN 'STABLE'
            ELSE 'DECLINING'
        END AS balance_trend,
        
        -- Digital engagement
        COALESCE(em.mobile_app_active, FALSE) AS mobile_app_active,
        COALESCE(em.login_count_30d, 0) AS login_count_30d,
        COALESCE(em.digital_engagement_score, 0) AS digital_engagement_score,
        
        -- Complaints
        COALESCE(cm.open_complaints_count, 0) AS open_complaints_count,
        COALESCE(cm.complaints_last_12m, 0) AS complaints_last_12m,
        COALESCE(cm.has_unresolved_complaint, FALSE) AS has_unresolved_complaint,
        
        -- ================================================================
        -- RISK DRIVER FLAGS (explainability)
        -- ================================================================
        
        -- Declining balance flag: Balance dropped significantly or very low
        CASE 
            WHEN am.total_relationship_balance < 500 THEN TRUE
            WHEN am.primary_account_balance < 100 THEN TRUE
            ELSE FALSE 
        END AS declining_balance_flag,
        
        -- Reduced activity flag: Transaction count dropped >30%
        CASE 
            WHEN COALESCE(tm.txn_count_prior_3m, 0) > 0 
                 AND tm.txn_count_recent_3m < tm.txn_count_prior_3m * 0.7 
            THEN TRUE 
            ELSE FALSE 
        END AS reduced_activity_flag,
        
        -- Low engagement flag: Minimal digital interaction
        CASE 
            WHEN COALESCE(em.login_count_30d, 0) < 3 
                 AND NOT COALESCE(em.mobile_app_active, FALSE)
            THEN TRUE 
            ELSE FALSE 
        END AS low_engagement_flag,
        
        -- Complaint flag: Open complaints or frequent complaints
        CASE 
            WHEN COALESCE(cm.open_complaints_count, 0) > 0 THEN TRUE
            WHEN COALESCE(cm.complaints_last_12m, 0) >= 2 THEN TRUE
            ELSE FALSE 
        END AS complaint_flag,
        
        -- Dormancy flag: No activity for extended period
        CASE 
            WHEN COALESCE(tm.days_since_last_txn, 999) > 45 THEN TRUE 
            ELSE FALSE 
        END AS dormancy_flag,
        
        -- ================================================================
        -- POSITIVE SIGNALS (reduce risk score)
        -- ================================================================
        CASE WHEN am.total_products_held >= 3 THEN TRUE ELSE FALSE END AS multi_product_customer,
        CASE WHEN DATEDIFF('month', c.onboarding_date, CURRENT_DATE()) > 60 THEN TRUE ELSE FALSE END AS long_tenure_customer,
        CASE WHEN em.digital_engagement_score > 70 THEN TRUE ELSE FALSE END AS highly_engaged_digital
        
    FROM customers c
    LEFT JOIN account_metrics am ON c.customer_id = am.customer_id
    LEFT JOIN transaction_metrics tm ON c.customer_id = tm.customer_id
    LEFT JOIN engagement_metrics em ON c.customer_id = em.customer_id
    LEFT JOIN complaint_metrics cm ON c.customer_id = cm.customer_id
),

-- ============================================================================
-- FINAL SCORING: Calculate risk score and classifications
-- ============================================================================

scored_customers AS (
    SELECT
        rs.*,
        
        -- ================================================================
        -- CHURN RISK SCORE CALCULATION (0-100)
        -- ================================================================
        LEAST(100, GREATEST(0,
            -- Base score
            20
            
            -- Risk factors (add points)
            + CASE WHEN declining_balance_flag THEN 20 ELSE 0 END
            + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
            + CASE WHEN low_engagement_flag THEN 15 ELSE 0 END
            + CASE WHEN complaint_flag THEN 15 ELSE 0 END
            + CASE WHEN dormancy_flag THEN 25 ELSE 0 END
            
            -- Protective factors (subtract points)
            - CASE WHEN multi_product_customer THEN 10 ELSE 0 END
            - CASE WHEN long_tenure_customer THEN 10 ELSE 0 END
            - CASE WHEN highly_engaged_digital THEN 10 ELSE 0 END
            
            -- Segment adjustment
            + CASE customer_segment
                WHEN 'MASS_MARKET' THEN 5      -- Slightly higher base risk
                WHEN 'HIGH_NET_WORTH' THEN -5  -- Lower base risk (more sticky)
                ELSE 0
              END
        )) AS churn_risk_score
        
    FROM risk_signals rs
)

-- ============================================================================
-- OUTPUT: Final data product
-- ============================================================================

SELECT
    -- Customer identifiers
    customer_id,
    customer_name,
    customer_segment,
    region,
    
    -- Relationship attributes
    relationship_tenure_months,
    total_products_held,
    primary_account_balance,
    total_relationship_balance,
    
    -- Behavioral signals
    avg_monthly_transactions_3m,
    transaction_trend,
    balance_trend,
    days_since_last_transaction,
    
    -- Digital engagement
    mobile_app_active,
    login_count_30d,
    digital_engagement_score,
    
    -- Complaints
    open_complaints_count,
    complaints_last_12m,
    has_unresolved_complaint,
    
    -- ================================================================
    -- CHURN RISK OUTPUTS (primary value of data product)
    -- ================================================================
    churn_risk_score,
    
    -- Risk tier classification
    CASE
        WHEN churn_risk_score <= 25 THEN 'LOW'
        WHEN churn_risk_score <= 50 THEN 'MEDIUM'
        WHEN churn_risk_score <= 75 THEN 'HIGH'
        ELSE 'CRITICAL'
    END AS risk_tier,
    
    -- Risk driver flags (explainability)
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    
    -- Primary risk driver (most significant factor)
    CASE
        WHEN dormancy_flag AND days_since_last_transaction > 60 THEN 'DORMANCY'
        WHEN declining_balance_flag AND primary_account_balance < 100 THEN 'BALANCE_DECLINE'
        WHEN reduced_activity_flag THEN 'ACTIVITY_REDUCTION'
        WHEN complaint_flag AND open_complaints_count > 0 THEN 'COMPLAINTS'
        WHEN low_engagement_flag THEN 'LOW_ENGAGEMENT'
        WHEN churn_risk_score > 50 THEN 'MULTI_FACTOR'
        ELSE 'NONE'
    END AS primary_risk_driver,
    
    -- All risk drivers as JSON (for detailed analysis)
    OBJECT_CONSTRUCT(
        'declining_balance', OBJECT_CONSTRUCT(
            'flag', declining_balance_flag,
            'balance', primary_account_balance
        ),
        'reduced_activity', OBJECT_CONSTRUCT(
            'flag', reduced_activity_flag,
            'trend', transaction_trend
        ),
        'low_engagement', OBJECT_CONSTRUCT(
            'flag', low_engagement_flag,
            'score', digital_engagement_score
        ),
        'complaints', OBJECT_CONSTRUCT(
            'flag', complaint_flag,
            'open_count', open_complaints_count,
            'total_12m', complaints_last_12m
        ),
        'dormancy', OBJECT_CONSTRUCT(
            'flag', dormancy_flag,
            'days_inactive', days_since_last_transaction
        )
    )::VARCHAR AS risk_drivers_json,
    
    -- ================================================================
    -- RECOMMENDED ACTIONS
    -- ================================================================
    CASE
        WHEN churn_risk_score > 75 THEN 'URGENT_ESCALATION'
        WHEN churn_risk_score > 50 AND complaint_flag THEN 'RELATIONSHIP_CALL'
        WHEN churn_risk_score > 50 THEN 'RETENTION_OFFER'
        WHEN churn_risk_score > 25 AND low_engagement_flag THEN 'DIGITAL_ENGAGEMENT'
        WHEN churn_risk_score > 25 THEN 'BRANCH_MEETING'
        ELSE 'NO_ACTION'
    END AS recommended_intervention,
    
    -- Priority for intervention queue (1 = highest)
    CASE
        WHEN churn_risk_score > 75 THEN 1
        WHEN churn_risk_score > 50 THEN 2
        WHEN churn_risk_score > 25 THEN 3
        ELSE 4
    END AS intervention_priority,
    
    -- ================================================================
    -- METADATA & AUDIT
    -- ================================================================
    CURRENT_TIMESTAMP() AS score_calculated_at,
    CURRENT_DATE() AS data_as_of_date,
    '1.0.0' AS model_version

FROM scored_customers

