-- ============================================================================
-- DELIVER: Data Quality Setup with Data Metric Functions (DMFs)
-- ============================================================================
-- This script sets up Data Metric Functions as part of data product delivery.
-- Quality rules are codified in the data contract and enforced here.
--
-- System DMFs: NULL_COUNT, DUPLICATE_COUNT, UNIQUE_COUNT, FRESHNESS, ROW_COUNT
--
-- Run this AFTER deploying the dbt model and masking policies.
-- Docs: https://docs.snowflake.com/en/user-guide/data-quality-intro
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;


-- ============================================================================
-- PART 1: SET DMF SCHEDULE
-- ============================================================================
-- Quality checks run automatically on a schedule.
-- This aligns with the contract SLA (daily refresh by 6 AM UTC).

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    SET DATA_METRIC_SCHEDULE = 'USING CRON 0,30 * * * * UTC';
    -- Runs every 30 minutes
    -- Alternative: 'TRIGGER_ON_CHANGES' to run only when data changes


-- ============================================================================
-- PART 2: COMPLETENESS CHECKS (NULL_COUNT)
-- ============================================================================
-- Contract requirement: Critical columns must not have null values.
-- These expectations come directly from the data contract's quality rules.

-- Primary key must never be null
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (customer_id)
    EXPECTATION no_null_customer_id (VALUE = 0);

-- Core risk score must always be present
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (churn_risk_score)
    EXPECTATION no_null_risk_score (VALUE = 0);

-- Risk classification must always be assigned
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (risk_tier)
    EXPECTATION no_null_risk_tier (VALUE = 0);

-- Segmentation required for downstream analytics
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (customer_segment)
    EXPECTATION no_null_segment (VALUE = 0);

-- Every customer needs an intervention recommendation
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (recommended_intervention)
    EXPECTATION no_null_intervention (VALUE = 0);


-- ============================================================================
-- PART 3: UNIQUENESS CHECK (DUPLICATE_COUNT)
-- ============================================================================
-- Contract requirement: customer_id must be unique (primary key).

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT 
    ON (customer_id)
    EXPECTATION no_duplicate_customer_id (VALUE = 0);


-- ============================================================================
-- PART 4: CARDINALITY TRACKING (UNIQUE_COUNT)
-- ============================================================================
-- Track distinct values for key dimensions (informational, no expectations).
-- Helps detect data drift and unexpected changes in distributions.

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


-- ============================================================================
-- PART 5: FRESHNESS SLA (FRESHNESS)
-- ============================================================================
-- Contract SLA: Data refreshed daily by 6 AM UTC (max age: 24 hours).
-- 86400 seconds = 24 hours

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS 
    ON (score_calculated_at)
    EXPECTATION freshness_sla_24h (VALUE <= 86400);


-- ============================================================================
-- PART 6: ROW COUNT THRESHOLD (ROW_COUNT)
-- ============================================================================
-- Business expectation: Always have at least 500 customers scored.
-- Protects against accidental data loss or failed loads.

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT 
    ON ()
    EXPECTATION min_row_count_500 (VALUE >= 500);


-- ============================================================================
-- PART 7: VERIFY DMF CONFIGURATION
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

-- View all expectations defined (these are the contract's quality rules)
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
-- PART 8: INITIAL QUALITY CHECK
-- ============================================================================
-- Run immediately to verify the data product meets quality expectations.

SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(
    REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'));


-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- Summary of quality rules deployed (from data contract):
-- 
-- Completeness:
--   • customer_id: no nulls allowed
--   • churn_risk_score: no nulls allowed  
--   • risk_tier: no nulls allowed
--   • customer_segment: no nulls allowed
--   • recommended_intervention: no nulls allowed
--
-- Uniqueness:
--   • customer_id: must be unique (primary key)
--
-- Freshness:
--   • score_calculated_at: max 24 hours old (SLA)
--
-- Volume:
--   • Minimum 500 rows expected
--
-- Next: Run 04_operate/monitoring_observability.sql to set up ongoing monitoring.
-- ============================================================================
