-- ============================================================================
-- REFINE: Data Product Evolution Example
-- ============================================================================
-- This script demonstrates how to evolve and refine the Retail Customer 
-- Churn Risk data product over time based on:
-- - Business feedback
-- - Operational learnings
-- - Regulatory changes
-- - Usage patterns
--
-- Example scenario: After several quarters, telemetry shows the churn product 
-- works well for mass-market customers but less well for SMEs. The team decides 
-- to split the product into two specialized versions.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- SCENARIO: PRODUCT SPLIT - Retail vs SME Churn Risk
-- ============================================================================
-- 
-- BUSINESS CONTEXT:
-- After 6 months of operating the Retail Customer Churn Risk product:
-- 
-- 1. Telemetry shows that the model performs well for MASS_MARKET and 
--    MASS_AFFLUENT segments (74% accuracy) but poorly for SME-like 
--    behaviors in AFFLUENT segment (52% accuracy)
-- 
-- 2. Branch feedback indicates SME customers (businesses using personal 
--    accounts) have different churn drivers:
--    - Cash flow seasonality matters more than login frequency
--    - Complaint patterns are different (service fees vs. digital issues)
--    - Relationship manager engagement is more predictive than app usage
--
-- 3. Regulatory guidance (FCA Consumer Duty) suggests different treatment
--    for sole traders and micro-businesses
--
-- DECISION: Split into two specialized data products:
-- - RETAIL_CUSTOMER_CHURN_RISK (v2.0) - Pure retail consumers
-- - SME_CUSTOMER_CHURN_RISK (v1.0) - Small business customers
-- ============================================================================


-- ============================================================================
-- STEP 1: VERSION THE EXISTING PRODUCT
-- ============================================================================
-- Before making changes, create a versioned snapshot of the current product

-- Archive the current version
CREATE OR REPLACE TABLE RETAIL_CUSTOMER_CHURN_RISK_V1_ARCHIVE AS
SELECT 
    *,
    '1.0.0' AS archive_version,
    CURRENT_TIMESTAMP() AS archived_at,
    'Split into Retail and SME products' AS archive_reason
FROM RETAIL_CUSTOMER_CHURN_RISK;

-- Add version tracking to the archive
COMMENT ON TABLE RETAIL_CUSTOMER_CHURN_RISK_V1_ARCHIVE IS 
'Archived version 1.0.0 of Retail Customer Churn Risk - superseded by v2.0 (retail-only) and SME v1.0';


-- ============================================================================
-- STEP 2: UPDATE THE DATA CONTRACT (Conceptual - would be in YAML)
-- ============================================================================
/*
Changes to churn_risk_data_contract.yaml (v2.0.0):

metadata:
  version: "2.0.0"  # Bumped from 1.0.0
  changelog:
    - version: "2.0.0"
      date: "2024-07-15"
      changes:
        - "Restricted to pure retail customers (excludes SME indicators)"
        - "Added SME exclusion flags"
        - "Recalibrated risk weights for retail behaviors"
        - "See SME_CUSTOMER_CHURN_RISK for business customers"

spec:
  schema:
    filters:
      # NEW: Exclude customers with SME indicators
      - "customer_segment NOT IN ('BUSINESS', 'SME')"
      - "NOT has_business_account_flag"
      - "monthly_transaction_count < 500"  # High volume suggests business use
*/


-- ============================================================================
-- STEP 3: CREATE THE NEW RETAIL-ONLY PRODUCT (v2.0)
-- ============================================================================

CREATE OR REPLACE TABLE RETAIL_CUSTOMER_CHURN_RISK_V2 AS
WITH 
-- Identify customers with SME-like behaviors to exclude
sme_indicators AS (
    SELECT 
        customer_id,
        -- Flag customers showing business-like patterns
        CASE 
            WHEN avg_monthly_transactions_3m > 150 THEN TRUE
            WHEN total_relationship_balance > 100000 THEN TRUE
            WHEN total_products_held > 5 THEN TRUE
            ELSE FALSE
        END AS has_sme_indicators
    FROM RETAIL_CUSTOMER_CHURN_RISK
),

-- Recalibrated risk scoring for pure retail
retail_rescored AS (
    SELECT 
        r.*,
        s.has_sme_indicators,
        
        -- Recalibrated churn risk score for retail
        -- (Retail customers: digital engagement matters more)
        LEAST(100, GREATEST(0,
            15  -- Lower base for retail
            + CASE WHEN r.declining_balance_flag THEN 15 ELSE 0 END
            + CASE WHEN r.reduced_activity_flag THEN 15 ELSE 0 END
            + CASE WHEN r.low_engagement_flag THEN 25 ELSE 0 END  -- Higher weight for retail
            + CASE WHEN r.complaint_flag THEN 15 ELSE 0 END
            + CASE WHEN r.dormancy_flag THEN 20 ELSE 0 END
            - CASE WHEN r.total_products_held >= 3 THEN 15 ELSE 0 END
            - CASE WHEN r.relationship_tenure_months > 36 THEN 10 ELSE 0 END
            - CASE WHEN r.digital_engagement_score > 60 THEN 15 ELSE 0 END  -- Higher weight
        )) AS churn_risk_score_v2
        
    FROM RETAIL_CUSTOMER_CHURN_RISK r
    JOIN sme_indicators s ON r.customer_id = s.customer_id
)

SELECT 
    customer_id,
    customer_name,
    customer_segment,
    region,
    relationship_tenure_months,
    total_products_held,
    primary_account_balance,
    total_relationship_balance,
    avg_monthly_transactions_3m,
    transaction_trend,
    balance_trend,
    days_since_last_transaction,
    mobile_app_active,
    login_count_30d,
    digital_engagement_score,
    open_complaints_count,
    complaints_last_12m,
    has_unresolved_complaint,
    
    -- Updated risk outputs
    churn_risk_score_v2 AS churn_risk_score,
    
    CASE
        WHEN churn_risk_score_v2 <= 25 THEN 'LOW'
        WHEN churn_risk_score_v2 <= 50 THEN 'MEDIUM'
        WHEN churn_risk_score_v2 <= 75 THEN 'HIGH'
        ELSE 'CRITICAL'
    END AS risk_tier,
    
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    
    -- Updated primary driver (digital more important for retail)
    CASE
        WHEN low_engagement_flag AND digital_engagement_score < 30 THEN 'LOW_ENGAGEMENT'
        WHEN dormancy_flag THEN 'DORMANCY'
        WHEN declining_balance_flag THEN 'BALANCE_DECLINE'
        WHEN reduced_activity_flag THEN 'ACTIVITY_REDUCTION'
        WHEN complaint_flag THEN 'COMPLAINTS'
        ELSE 'MULTI_FACTOR'
    END AS primary_risk_driver,
    
    risk_drivers_json,
    recommended_intervention,
    intervention_priority,
    CURRENT_TIMESTAMP() AS score_calculated_at,
    CURRENT_DATE() AS data_as_of_date,
    '2.0.0' AS model_version,
    
    -- New fields for v2
    has_sme_indicators,
    'RETAIL' AS customer_type
    
FROM retail_rescored
WHERE has_sme_indicators = FALSE  -- Exclude SME-like customers
  AND customer_segment IN ('MASS_MARKET', 'MASS_AFFLUENT', 'AFFLUENT', 'HIGH_NET_WORTH');


-- ============================================================================
-- STEP 4: CREATE THE NEW SME PRODUCT (v1.0)
-- ============================================================================

CREATE OR REPLACE TABLE SME_CUSTOMER_CHURN_RISK AS
WITH 
sme_customers AS (
    SELECT 
        r.*,
        -- SME-specific risk factors
        CASE 
            WHEN r.avg_monthly_transactions_3m > 150 THEN TRUE
            WHEN r.total_relationship_balance > 100000 THEN TRUE
            WHEN r.total_products_held > 5 THEN TRUE
            ELSE FALSE
        END AS is_sme_like
    FROM RETAIL_CUSTOMER_CHURN_RISK r
),

-- SME-specific risk scoring
sme_scored AS (
    SELECT 
        *,
        -- SME churn drivers are different:
        -- - Cash flow (balance volatility) matters most
        -- - Relationship manager engagement > digital
        -- - Service fees complaints are key signals
        LEAST(100, GREATEST(0,
            20  -- Base score
            + CASE WHEN declining_balance_flag THEN 25 ELSE 0 END  -- Cash flow critical
            + CASE WHEN reduced_activity_flag THEN 20 ELSE 0 END
            + CASE WHEN complaint_flag AND complaints_last_12m > 1 THEN 20 ELSE 0 END  -- Multiple complaints = service issue
            + CASE WHEN dormancy_flag THEN 15 ELSE 0 END
            + CASE WHEN low_engagement_flag THEN 5 ELSE 0 END  -- Less important for SME
            - CASE WHEN total_products_held >= 4 THEN 15 ELSE 0 END  -- Product stickiness very important
            - CASE WHEN relationship_tenure_months > 24 THEN 10 ELSE 0 END
            - CASE WHEN total_relationship_balance > 50000 THEN 10 ELSE 0 END  -- Balance = commitment
        )) AS sme_churn_risk_score
    FROM sme_customers
    WHERE is_sme_like = TRUE
)

SELECT 
    customer_id,
    customer_name,
    customer_segment,
    region,
    relationship_tenure_months,
    total_products_held,
    primary_account_balance,
    total_relationship_balance,
    avg_monthly_transactions_3m,
    transaction_trend,
    balance_trend,
    days_since_last_transaction,
    mobile_app_active,
    login_count_30d,
    digital_engagement_score,
    open_complaints_count,
    complaints_last_12m,
    has_unresolved_complaint,
    
    sme_churn_risk_score AS churn_risk_score,
    
    CASE
        WHEN sme_churn_risk_score <= 25 THEN 'LOW'
        WHEN sme_churn_risk_score <= 50 THEN 'MEDIUM'
        WHEN sme_churn_risk_score <= 75 THEN 'HIGH'
        ELSE 'CRITICAL'
    END AS risk_tier,
    
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    
    -- SME-specific primary driver priorities
    CASE
        WHEN declining_balance_flag AND balance_trend = 'SEVERELY_DECLINING' THEN 'CASH_FLOW_STRESS'
        WHEN complaint_flag AND complaints_last_12m > 1 THEN 'SERVICE_DISSATISFACTION'
        WHEN reduced_activity_flag THEN 'ACTIVITY_REDUCTION'
        WHEN dormancy_flag THEN 'DORMANCY'
        ELSE 'MULTI_FACTOR'
    END AS primary_risk_driver,
    
    -- SME-specific interventions
    CASE
        WHEN sme_churn_risk_score > 75 THEN 'RM_URGENT_REVIEW'
        WHEN sme_churn_risk_score > 50 AND complaint_flag THEN 'SERVICE_RECOVERY_CALL'
        WHEN sme_churn_risk_score > 50 THEN 'BUSINESS_REVIEW_MEETING'
        WHEN sme_churn_risk_score > 25 THEN 'PROACTIVE_RM_CONTACT'
        ELSE 'STANDARD_MONITORING'
    END AS recommended_intervention,
    
    CASE
        WHEN sme_churn_risk_score > 75 THEN 1
        WHEN sme_churn_risk_score > 50 THEN 2
        WHEN sme_churn_risk_score > 25 THEN 3
        ELSE 4
    END AS intervention_priority,
    
    CURRENT_TIMESTAMP() AS score_calculated_at,
    CURRENT_DATE() AS data_as_of_date,
    '1.0.0' AS model_version,
    'SME' AS customer_type,
    
    -- SME-specific metrics
    avg_monthly_transactions_3m AS monthly_transaction_volume,
    CASE 
        WHEN avg_monthly_transactions_3m > 300 THEN 'HIGH_VOLUME'
        WHEN avg_monthly_transactions_3m > 100 THEN 'MEDIUM_VOLUME'
        ELSE 'LOW_VOLUME'
    END AS transaction_volume_tier

FROM sme_scored;


-- ============================================================================
-- STEP 5: RETIRE THE LEGACY SPREADSHEET REPORT
-- ============================================================================
-- Document the retirement of the old manual churn report

CREATE OR REPLACE TABLE RETIRED_DATA_ASSETS (
    asset_id            VARCHAR(50) DEFAULT UUID_STRING(),
    asset_name          VARCHAR(200),
    asset_type          VARCHAR(50),
    retirement_date     DATE,
    replacement_product VARCHAR(200),
    migration_notes     VARCHAR(1000),
    archived_location   VARCHAR(500),
    owner_notified      BOOLEAN,
    consumers_migrated  BOOLEAN,
    PRIMARY KEY (asset_id)
);

INSERT INTO RETIRED_DATA_ASSETS (
    asset_name, asset_type, retirement_date, replacement_product, 
    migration_notes, archived_location, owner_notified, consumers_migrated
) VALUES (
    'Monthly Churn Analysis Spreadsheet',
    'SPREADSHEET',
    CURRENT_DATE(),
    'RETAIL_CUSTOMER_CHURN_RISK_V2 + SME_CUSTOMER_CHURN_RISK',
    'Legacy Excel-based churn report maintained by Branch Ops. Replaced by governed data products with daily refresh, audit trail, and explainability. All historical data preserved in archive.',
    's3://bank-data-archive/legacy/churn-spreadsheets/',
    TRUE,
    TRUE
);


-- ============================================================================
-- STEP 6: UPDATE CONSUMERS
-- ============================================================================
-- Communicate changes and update access

-- Create a migration view for backward compatibility during transition
CREATE OR REPLACE VIEW RETAIL_CUSTOMER_CHURN_RISK AS
SELECT 
    customer_id,
    customer_name,
    customer_segment,
    region,
    relationship_tenure_months,
    total_products_held,
    primary_account_balance,
    total_relationship_balance,
    avg_monthly_transactions_3m,
    transaction_trend,
    balance_trend,
    days_since_last_transaction,
    mobile_app_active,
    login_count_30d,
    digital_engagement_score,
    open_complaints_count,
    complaints_last_12m,
    has_unresolved_complaint,
    churn_risk_score,
    risk_tier,
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    primary_risk_driver,
    risk_drivers_json,
    recommended_intervention,
    intervention_priority,
    score_calculated_at,
    data_as_of_date,
    model_version
FROM RETAIL_CUSTOMER_CHURN_RISK_V2

UNION ALL

SELECT 
    customer_id,
    customer_name,
    customer_segment,
    region,
    relationship_tenure_months,
    total_products_held,
    primary_account_balance,
    total_relationship_balance,
    avg_monthly_transactions_3m,
    transaction_trend,
    balance_trend,
    days_since_last_transaction,
    mobile_app_active,
    login_count_30d,
    digital_engagement_score,
    open_complaints_count,
    complaints_last_12m,
    has_unresolved_complaint,
    churn_risk_score,
    risk_tier,
    declining_balance_flag,
    reduced_activity_flag,
    low_engagement_flag,
    complaint_flag,
    dormancy_flag,
    primary_risk_driver,
    NULL AS risk_drivers_json,  -- Schema alignment
    recommended_intervention,
    intervention_priority,
    score_calculated_at,
    data_as_of_date,
    model_version
FROM SME_CUSTOMER_CHURN_RISK;

COMMENT ON VIEW RETAIL_CUSTOMER_CHURN_RISK IS 
'DEPRECATED: This view combines Retail V2 and SME products for backward compatibility. 
Please migrate to RETAIL_CUSTOMER_CHURN_RISK_V2 or SME_CUSTOMER_CHURN_RISK directly.
Deprecation date: 2024-07-15 | Sunset date: 2024-10-15';


-- ============================================================================
-- STEP 7: UPDATE DOCUMENTATION AND LINEAGE
-- ============================================================================

-- Product lineage tracking
CREATE OR REPLACE TABLE DATA_PRODUCT_LINEAGE (
    lineage_id          VARCHAR(50) DEFAULT UUID_STRING(),
    parent_product      VARCHAR(200),
    parent_version      VARCHAR(20),
    child_product       VARCHAR(200),
    child_version       VARCHAR(20),
    relationship_type   VARCHAR(50),  -- SPLIT, MERGE, EVOLVED, REPLACED
    effective_date      DATE,
    notes               VARCHAR(1000),
    PRIMARY KEY (lineage_id)
);

INSERT INTO DATA_PRODUCT_LINEAGE (
    parent_product, parent_version, child_product, child_version, 
    relationship_type, effective_date, notes
) VALUES 
    ('RETAIL_CUSTOMER_CHURN_RISK', '1.0.0', 'RETAIL_CUSTOMER_CHURN_RISK_V2', '2.0.0', 
     'EVOLVED', CURRENT_DATE(), 
     'Retail-focused version with recalibrated scoring for pure consumer customers'),
    ('RETAIL_CUSTOMER_CHURN_RISK', '1.0.0', 'SME_CUSTOMER_CHURN_RISK', '1.0.0', 
     'SPLIT', CURRENT_DATE(), 
     'New product for SME-like customers with business-specific risk drivers');


-- ============================================================================
-- STEP 8: SUMMARY COMPARISON
-- ============================================================================

-- Compare the original vs split products
SELECT 
    'Original v1.0' AS product_version,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS high_risk_count,
    ROUND(AVG(churn_risk_score), 1) AS avg_risk_score
FROM RETAIL_CUSTOMER_CHURN_RISK_V1_ARCHIVE

UNION ALL

SELECT 
    'Retail v2.0' AS product_version,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS high_risk_count,
    ROUND(AVG(churn_risk_score), 1) AS avg_risk_score
FROM RETAIL_CUSTOMER_CHURN_RISK_V2

UNION ALL

SELECT 
    'SME v1.0' AS product_version,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS high_risk_count,
    ROUND(AVG(churn_risk_score), 1) AS avg_risk_score
FROM SME_CUSTOMER_CHURN_RISK;


-- ============================================================================
-- EVOLUTION COMPLETE
-- ============================================================================
-- Summary:
-- 1. Archived original product (v1.0) for audit trail
-- 2. Created specialized Retail product (v2.0) with recalibrated scoring
-- 3. Created new SME product (v1.0) with business-specific drivers
-- 4. Retired legacy spreadsheet with documentation
-- 5. Created backward-compatible view for transition period
-- 6. Updated lineage tracking
--
-- Next steps:
-- - Update data contracts for both new products
-- - Notify consumers of migration timeline
-- - Update monitoring for new products
-- - Schedule sunset of deprecated view (3 months)
-- ============================================================================

