-- ============================================================================
-- CLEANUP: Remove Monitoring Resources
-- ============================================================================
-- Run this before re-running 03_deliver/02_data_quality_dmf.sql 
-- or 04_operate/monitoring_observability.sql
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;

-- ============================================================================
-- PART 1: REMOVE ALERTS
-- ============================================================================

SELECT '🗑️  Removing alerts...' AS status;

BEGIN
    ALTER ALERT IF EXISTS MONITORING.freshness_sla_alert SUSPEND;
EXCEPTION WHEN OTHER THEN NULL;
END;

BEGIN
    ALTER ALERT IF EXISTS MONITORING.quality_expectation_alert SUSPEND;
EXCEPTION WHEN OTHER THEN NULL;
END;

BEGIN
    ALTER ALERT IF EXISTS MONITORING.row_count_anomaly_alert SUSPEND;
EXCEPTION WHEN OTHER THEN NULL;
END;

DROP ALERT IF EXISTS MONITORING.freshness_sla_alert;
DROP ALERT IF EXISTS MONITORING.quality_expectation_alert;
DROP ALERT IF EXISTS MONITORING.row_count_anomaly_alert;

-- ============================================================================
-- PART 2: REMOVE MONITORING VIEW
-- ============================================================================

SELECT '🗑️  Removing monitoring views...' AS status;

DROP VIEW IF EXISTS MONITORING.data_product_health_summary;

-- ============================================================================
-- PART 3: REMOVE DMFs
-- ============================================================================

SELECT '🗑️  Removing DMFs from table...' AS status;

-- Remove all DMFs using Snowflake Scripting (handles errors if not attached)
BEGIN
    -- NULL_COUNT
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (customer_id);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (churn_risk_score);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (risk_tier);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (customer_segment);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (recommended_intervention);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    
    -- DUPLICATE_COUNT
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (customer_id);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    
    -- UNIQUE_COUNT
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (customer_id);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (risk_tier);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (customer_segment);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (region);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (primary_risk_driver);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (recommended_intervention);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    
    -- FRESHNESS
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (score_calculated_at);
    EXCEPTION WHEN OTHER THEN NULL;
    END;
    
    -- ROW_COUNT
    BEGIN
        ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
            DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ();
    EXCEPTION WHEN OTHER THEN NULL;
    END;
END;

-- Unset schedule
BEGIN
    ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
        UNSET DATA_METRIC_SCHEDULE;
EXCEPTION WHEN OTHER THEN NULL;
END;

SELECT '✅ Monitoring cleanup complete!' AS status;

-- ============================================================================
-- CLEANUP SUMMARY
-- ============================================================================
-- Removed:
--   • Alerts: freshness_sla_alert, quality_expectation_alert, row_count_anomaly_alert
--   • Views: data_product_health_summary
--   • DMFs: NULL_COUNT, DUPLICATE_COUNT, UNIQUE_COUNT, FRESHNESS, ROW_COUNT
--   • DMF Schedule on RETAIL_CUSTOMER_CHURN_RISK table
-- ============================================================================
