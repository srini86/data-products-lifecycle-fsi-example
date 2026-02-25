-- =============================================================================
-- DATA METRIC FUNCTIONS (DMF) SETUP: Retail Customer Churn Risk
-- =============================================================================
-- Generated from: 02_design/retail_churn_contract.yaml
--
-- DMFs provide continuous data quality monitoring in Snowflake.
-- These are applied based on quality_rules defined in the contract.
-- =============================================================================

USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- =============================================================================
-- GRANT PERMISSIONS FOR DMF
-- =============================================================================
-- DMFs require specific permissions to run

GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE DATA_PRODUCTS_ROLE;

-- =============================================================================
-- COMPLETENESS CHECKS (NULL_COUNT)
-- =============================================================================
-- Contract Rule: core_fields_completeness - threshold 100%
-- These columns must never be null

-- customer_id completeness
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (customer_id);

-- customer_name completeness
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (customer_name);

-- churn_risk_score completeness
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (churn_risk_score);

-- risk_tier completeness
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (risk_tier);

-- primary_risk_driver completeness
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (primary_risk_driver);

-- recommended_intervention completeness
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (recommended_intervention);

-- score_calculated_at completeness
ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT
    ON (score_calculated_at);

-- =============================================================================
-- UNIQUENESS CHECKS (DUPLICATE_COUNT)
-- =============================================================================
-- Contract Rule: customer_id_uniqueness - threshold 100%

ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
    ON (customer_id);

-- =============================================================================
-- ROW COUNT CHECK
-- =============================================================================
-- Contract Rule: minimum_customer_count - min 1000 rows
-- Note: ROW_COUNT is a system DMF that tracks table size

ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT
    ON ();

-- =============================================================================
-- FRESHNESS CHECK
-- =============================================================================
-- Contract SLA: freshness_hours: 24
-- Monitor the score_calculated_at column to ensure data is fresh

ALTER TABLE RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS
    ON (score_calculated_at);

-- =============================================================================
-- VIEW DMF RESULTS
-- =============================================================================
-- Query to check DMF results after they run:

/*
SELECT 
    measurement_time,
    metric_database,
    metric_schema,
    metric_name,
    table_database,
    table_schema,
    table_name,
    column_name,
    value
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY measurement_time DESC
LIMIT 100;
*/

-- =============================================================================
-- ALERTING (Optional - requires ACCOUNTADMIN)
-- =============================================================================
-- Create alerts for DMF threshold violations

/*
-- Alert when NULL_COUNT > 0 for required fields
CREATE OR REPLACE ALERT dmf_alert_null_customer_id
    WAREHOUSE = DATA_PRODUCTS_WH
    SCHEDULE = 'USING CRON 0 7 * * * UTC'  -- Daily at 7 AM UTC (after 6 AM refresh)
    IF (EXISTS (
        SELECT 1 FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
        WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
          AND metric_name = 'NULL_COUNT'
          AND column_name = 'CUSTOMER_ID'
          AND value > 0
          AND measurement_time > DATEADD(hour, -24, CURRENT_TIMESTAMP())
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'retail-data-support@bank.com',
            'DMF Alert: NULL values in CUSTOMER_ID',
            'Data quality check failed for RETAIL_CUSTOMER_CHURN_RISK.customer_id'
        );

-- Alert when DUPLICATE_COUNT > 0
CREATE OR REPLACE ALERT dmf_alert_duplicate_customer_id
    WAREHOUSE = DATA_PRODUCTS_WH
    SCHEDULE = 'USING CRON 0 7 * * * UTC'
    IF (EXISTS (
        SELECT 1 FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
        WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
          AND metric_name = 'DUPLICATE_COUNT'
          AND column_name = 'CUSTOMER_ID'
          AND value > 0
          AND measurement_time > DATEADD(hour, -24, CURRENT_TIMESTAMP())
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'retail-data-support@bank.com',
            'DMF Alert: Duplicate CUSTOMER_ID values',
            'Uniqueness check failed for RETAIL_CUSTOMER_CHURN_RISK.customer_id'
        );

-- Alert when ROW_COUNT < 1000
CREATE OR REPLACE ALERT dmf_alert_low_row_count
    WAREHOUSE = DATA_PRODUCTS_WH
    SCHEDULE = 'USING CRON 0 7 * * * UTC'
    IF (EXISTS (
        SELECT 1 FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
        WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
          AND metric_name = 'ROW_COUNT'
          AND value < 1000
          AND measurement_time > DATEADD(hour, -24, CURRENT_TIMESTAMP())
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'retail-data-support@bank.com',
            'DMF Alert: Low row count',
            'Row count < 1000 for RETAIL_CUSTOMER_CHURN_RISK'
        );
*/

-- =============================================================================
-- SUMMARY
-- =============================================================================
-- DMFs Applied:
-- 1. NULL_COUNT on: customer_id, customer_name, churn_risk_score, risk_tier,
--                   primary_risk_driver, recommended_intervention, score_calculated_at
-- 2. DUPLICATE_COUNT on: customer_id
-- 3. ROW_COUNT on: table level
-- 4. FRESHNESS on: score_calculated_at
--
-- Schedule: TRIGGER_ON_CHANGES (runs after each table update)
-- SLA: Data must be refreshed within 24 hours
