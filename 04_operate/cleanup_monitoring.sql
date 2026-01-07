-- ============================================================================
-- CLEANUP: Remove Monitoring & Observability Resources
-- ============================================================================
-- This script removes all resources created by monitoring_observability.sql
-- Run this before re-running monitoring_observability.sql to avoid conflicts
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;

-- ============================================================================
-- STEP 1: SUSPEND AND DROP ALERTS
-- ============================================================================

SELECT '🗑️  Step 1: Dropping alerts...' AS status;

ALTER ALERT IF EXISTS MONITORING.dq_failure_alert SUSPEND;
ALTER ALERT IF EXISTS MONITORING.freshness_breach_alert SUSPEND;

DROP ALERT IF EXISTS MONITORING.dq_failure_alert;
DROP ALERT IF EXISTS MONITORING.freshness_breach_alert;

SELECT '✅ Alerts dropped' AS status;


-- ============================================================================
-- STEP 2: DROP DMFs FROM TABLE (Remove associations and expectations)
-- ============================================================================

SELECT '🗑️  Step 2: Removing DMFs from table...' AS status;

-- Drop System DMFs
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS SNOWFLAKE.CORE.NULL_COUNT ON (customer_id);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS SNOWFLAKE.CORE.NULL_COUNT ON (churn_risk_score);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS SNOWFLAKE.CORE.NULL_COUNT ON (risk_tier);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS SNOWFLAKE.CORE.DUPLICATE_COUNT ON (customer_id);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS SNOWFLAKE.CORE.UNIQUE_COUNT ON (customer_id);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS SNOWFLAKE.CORE.UNIQUE_COUNT ON (risk_tier);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS SNOWFLAKE.CORE.FRESHNESS ON (score_calculated_at);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS SNOWFLAKE.CORE.ROW_COUNT ON ();

-- Drop Custom DMFs from table
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS MONITORING.risk_score_out_of_range ON (churn_risk_score);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS MONITORING.risk_tier_misalignment ON (churn_risk_score, risk_tier);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS MONITORING.invalid_risk_tier ON (risk_tier);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    DROP DATA METRIC FUNCTION IF EXISTS MONITORING.high_risk_percentage ON (risk_tier);

SELECT '✅ DMFs removed from table' AS status;


-- ============================================================================
-- STEP 3: UNSET DATA METRIC SCHEDULE
-- ============================================================================

SELECT '🗑️  Step 3: Unsetting data metric schedule...' AS status;

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    UNSET DATA_METRIC_SCHEDULE;

SELECT '✅ Data metric schedule unset' AS status;


-- ============================================================================
-- STEP 4: DROP CUSTOM DMF DEFINITIONS
-- ============================================================================

SELECT '🗑️  Step 4: Dropping custom DMF definitions...' AS status;

DROP DATA METRIC FUNCTION IF EXISTS MONITORING.risk_score_out_of_range;
DROP DATA METRIC FUNCTION IF EXISTS MONITORING.risk_tier_misalignment;
DROP DATA METRIC FUNCTION IF EXISTS MONITORING.invalid_risk_tier;
DROP DATA METRIC FUNCTION IF EXISTS MONITORING.high_risk_percentage;

SELECT '✅ Custom DMFs dropped' AS status;


-- ============================================================================
-- STEP 5: DROP MONITORING VIEWS
-- ============================================================================

SELECT '🗑️  Step 5: Dropping monitoring views...' AS status;

DROP VIEW IF EXISTS MONITORING.dmf_configuration;
DROP VIEW IF EXISTS MONITORING.dmf_expectations;
DROP VIEW IF EXISTS MONITORING.expectation_violations;
DROP VIEW IF EXISTS MONITORING.data_quality_results;
DROP VIEW IF EXISTS MONITORING.data_quality_summary;
DROP VIEW IF EXISTS MONITORING.data_freshness_status;
DROP VIEW IF EXISTS MONITORING.row_count_status;
DROP VIEW IF EXISTS MONITORING.data_product_usage;
DROP VIEW IF EXISTS MONITORING.usage_by_consumer;
DROP VIEW IF EXISTS MONITORING.daily_usage_trends;
DROP VIEW IF EXISTS MONITORING.data_product_health_summary;
DROP VIEW IF EXISTS MONITORING.risk_distribution_summary;

SELECT '✅ Monitoring views dropped' AS status;


-- ============================================================================
-- STEP 6: DROP ALERT LOG TABLE
-- ============================================================================

SELECT '🗑️  Step 6: Dropping alert log table...' AS status;

DROP TABLE IF EXISTS MONITORING.alert_log;

SELECT '✅ Alert log table dropped' AS status;


-- ============================================================================
-- STEP 7: OPTIONALLY DROP MONITORING SCHEMA
-- ============================================================================
-- Uncomment the line below to drop the entire MONITORING schema
-- WARNING: This will remove ALL objects in the schema

-- DROP SCHEMA IF EXISTS MONITORING CASCADE;


-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================

SELECT '═══════════════════════════════════════════════════════════' AS msg
UNION ALL SELECT '              🧹 MONITORING CLEANUP COMPLETE!              '
UNION ALL SELECT '═══════════════════════════════════════════════════════════'
UNION ALL SELECT ''
UNION ALL SELECT 'Removed:'
UNION ALL SELECT '  • DMF associations (NULL_COUNT, DUPLICATE_COUNT, etc.)'
UNION ALL SELECT '  • Expectations (no_null_customer_id, freshness_sla_24h, etc.)'
UNION ALL SELECT '  • Custom DMFs (risk_score_out_of_range, etc.)'
UNION ALL SELECT '  • Monitoring views (dmf_configuration, data_quality_results, etc.)'
UNION ALL SELECT '  • Alerts (dq_failure_alert, freshness_breach_alert)'
UNION ALL SELECT '  • Alert log table'
UNION ALL SELECT ''
UNION ALL SELECT 'To recreate monitoring, run:'
UNION ALL SELECT '  04_operate/monitoring_observability.sql'
UNION ALL SELECT ''
UNION ALL SELECT '═══════════════════════════════════════════════════════════';

