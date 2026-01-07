-- ============================================================================
-- OPERATE: Monitoring & Observability for Retail Customer Churn Risk
-- ============================================================================
-- This script uses SNOWFLAKE NATIVE SYSTEM DMFs only.
-- Monitor results via Snowsight Data Quality dashboard.
--
-- System DMFs: NULL_COUNT, DUPLICATE_COUNT, UNIQUE_COUNT, FRESHNESS, ROW_COUNT
--
-- Docs: https://docs.snowflake.com/en/user-guide/data-quality-intro
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;

-- Create monitoring schema
CREATE SCHEMA IF NOT EXISTS MONITORING;
USE SCHEMA MONITORING;


-- ============================================================================
-- PART 1: SET SCHEDULE (REQUIRED BEFORE ADDING DMFs)
-- ============================================================================

-- Set monitoring schedule - DMFs run automatically every 30 minutes
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    SET DATA_METRIC_SCHEDULE = 'USING CRON 0,30 * * * * UTC';
    -- Alternative: 'TRIGGER_ON_CHANGES' to run only when data changes


-- ============================================================================
-- PART 2: SYSTEM DATA METRIC FUNCTIONS (DMFs) WITH EXPECTATIONS
-- ============================================================================

-- 2a. NULL_COUNT on critical columns (Expect: 0 nulls)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (customer_id)
    EXPECTATION no_null_customer_id (VALUE = 0);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (churn_risk_score)
    EXPECTATION no_null_risk_score (VALUE = 0);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (risk_tier)
    EXPECTATION no_null_risk_tier (VALUE = 0);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (customer_segment)
    EXPECTATION no_null_segment (VALUE = 0);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (recommended_intervention)
    EXPECTATION no_null_intervention (VALUE = 0);


-- 2b. DUPLICATE_COUNT on primary key (Expect: 0 duplicates)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT 
    ON (customer_id)
    EXPECTATION no_duplicate_customer_id (VALUE = 0);


-- 2c. UNIQUE_COUNT for cardinality (informational)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (customer_id);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (risk_tier);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (customer_segment);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (region);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (primary_risk_driver);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (recommended_intervention);


-- 2d. FRESHNESS on timestamp column (Expect: <= 24 hours = 86400 sec)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS 
    ON (score_calculated_at)
    EXPECTATION freshness_sla_24h (VALUE <= 86400);


-- 2e. ROW_COUNT for completeness (Expect: >= 500 rows)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT 
    ON ()
    EXPECTATION min_row_count_500 (VALUE >= 500);


-- ============================================================================
-- PART 3: VERIFY DMF CONFIGURATION
-- ============================================================================

-- View all DMFs applied to the table
SELECT 
    metric_name,
    ref_arguments AS columns,
    schedule,
    schedule_status
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
        REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
)
ORDER BY metric_name;

-- View all expectations defined
SELECT 
    expectation_name,
    expectation_expression,
    metric_name,
    ref_arguments AS columns
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_EXPECTATIONS(
        REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
)
ORDER BY expectation_name;


-- ============================================================================
-- PART 4: TEST EXPECTATIONS IMMEDIATELY
-- ============================================================================
-- Run this to test expectations without waiting for the schedule

SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(
    REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'));


-- ============================================================================
-- PART 5: VIEW RESULTS IN SNOWSIGHT
-- ============================================================================
-- 
-- To view DMF results in Snowsight:
-- 1. Go to: Data → Databases → RETAIL_BANKING_DB → DATA_PRODUCTS → RETAIL_CUSTOMER_CHURN_RISK
-- 2. Click "Data Quality" tab
-- 3. View metrics, expectations, and history
--
-- Or query the results directly:

-- Latest DMF results
SELECT 
    measurement_time,
    metric_name,
    argument_names AS columns,
    value AS metric_value
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY measurement_time DESC, metric_name
LIMIT 50;

-- Expectation status
SELECT *
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY measurement_time DESC
LIMIT 20;


-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- Summary:
-- 
-- DMFs Applied with Expectations:
--   • NULL_COUNT on customer_id, churn_risk_score, risk_tier, customer_segment, recommended_intervention
--   • DUPLICATE_COUNT on customer_id
--   • UNIQUE_COUNT on customer_id, risk_tier, customer_segment, region, primary_risk_driver, recommended_intervention
--   • FRESHNESS on score_calculated_at (SLA: 24 hours)
--   • ROW_COUNT (min: 500 rows)
--
-- View results: Snowsight → Data Quality dashboard
-- Docs: https://docs.snowflake.com/en/user-guide/data-quality-intro
-- ============================================================================
