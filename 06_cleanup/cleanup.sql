-- ============================================================================
-- CLEANUP.SQL - Remove All Demo Resources
-- ============================================================================
-- This script removes all resources created by the data product demo.
--
-- WARNING: This will permanently delete:
--   - Database RETAIL_BANKING_DB (and all schemas, tables, data)
--   - Warehouse DATA_PRODUCTS_WH
--   - All Streamlit apps, stages, DMFs, alerts, and governance objects
--
-- USAGE:
--   snowsql -f 06_cleanup/cleanup.sql
--   -- OR run in Snowsight
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- CONFIRMATION PROMPT (Comment out after reviewing)
-- ============================================================================
-- Uncomment the line below to proceed with cleanup
-- SET CONFIRM_CLEANUP = TRUE;

SELECT '⚠️  WARNING: This will permanently delete all demo resources!' AS warning;
SELECT 'Review the script and uncomment SET CONFIRM_CLEANUP = TRUE to proceed.' AS instruction;


-- ============================================================================
-- STEP 1: REMOVE ALERTS
-- ============================================================================

SELECT '🗑️  Step 1: Removing alerts...' AS status;

BEGIN
    ALTER ALERT IF EXISTS RETAIL_BANKING_DB.MONITORING.freshness_sla_alert SUSPEND;
EXCEPTION WHEN OTHER THEN NULL;
END;

BEGIN
    ALTER ALERT IF EXISTS RETAIL_BANKING_DB.MONITORING.quality_expectation_alert SUSPEND;
EXCEPTION WHEN OTHER THEN NULL;
END;

BEGIN
    ALTER ALERT IF EXISTS RETAIL_BANKING_DB.MONITORING.row_count_anomaly_alert SUSPEND;
EXCEPTION WHEN OTHER THEN NULL;
END;

DROP ALERT IF EXISTS RETAIL_BANKING_DB.MONITORING.freshness_sla_alert;
DROP ALERT IF EXISTS RETAIL_BANKING_DB.MONITORING.quality_expectation_alert;
DROP ALERT IF EXISTS RETAIL_BANKING_DB.MONITORING.row_count_anomaly_alert;

SELECT '✅ Step 1 Complete: Alerts removed' AS status;


-- ============================================================================
-- STEP 2: REMOVE DMFs FROM TABLE
-- ============================================================================

SELECT '🗑️  Step 2: Removing DMFs from table...' AS status;

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

SELECT '✅ Step 2 Complete: DMFs removed' AS status;


-- ============================================================================
-- STEP 3: DROP STREAMLIT APPS
-- ============================================================================

SELECT '🗑️  Step 3: Dropping Streamlit apps...' AS status;

DROP STREAMLIT IF EXISTS RETAIL_BANKING_DB.GOVERNANCE.dbt_code_generator;

SELECT '✅ Step 3 Complete: Streamlit apps dropped' AS status;


-- ============================================================================
-- STEP 4: DROP DATABASE (Cascades to all schemas, tables, stages, etc.)
-- ============================================================================

SELECT '🗑️  Step 4: Dropping database RETAIL_BANKING_DB...' AS status;

DROP DATABASE IF EXISTS RETAIL_BANKING_DB CASCADE;

SELECT '✅ Step 4 Complete: Database dropped (all schemas, tables, stages removed)' AS status;


-- ============================================================================
-- STEP 5: DROP WAREHOUSE
-- ============================================================================

SELECT '🗑️  Step 5: Dropping warehouse DATA_PRODUCTS_WH...' AS status;

DROP WAREHOUSE IF EXISTS DATA_PRODUCTS_WH;

SELECT '✅ Step 5 Complete: Warehouse dropped' AS status;


-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================

SELECT '═══════════════════════════════════════════════════════════' AS msg
UNION ALL SELECT '                    🧹 CLEANUP COMPLETE!                     '
UNION ALL SELECT '═══════════════════════════════════════════════════════════'
UNION ALL SELECT ''
UNION ALL SELECT 'The following resources have been removed:'
UNION ALL SELECT '  • Alerts: freshness_sla_alert, quality_expectation_alert,'
UNION ALL SELECT '            row_count_anomaly_alert'
UNION ALL SELECT '  • DMFs: NULL_COUNT, DUPLICATE_COUNT, UNIQUE_COUNT,'
UNION ALL SELECT '          FRESHNESS, ROW_COUNT on RETAIL_CUSTOMER_CHURN_RISK'
UNION ALL SELECT '  • Database: RETAIL_BANKING_DB'
UNION ALL SELECT '    - Schema: RAW (and all source tables)'
UNION ALL SELECT '    - Schema: DATA_PRODUCTS (and all data product tables)'
UNION ALL SELECT '    - Schema: GOVERNANCE (stages, Streamlit apps)'
UNION ALL SELECT '    - Schema: MONITORING (views, alerts)'
UNION ALL SELECT '  • Warehouse: DATA_PRODUCTS_WH'
UNION ALL SELECT ''
UNION ALL SELECT 'To recreate the demo environment, run:'
UNION ALL SELECT '  snowsql -f 00_setup/setup.sql'
UNION ALL SELECT ''
UNION ALL SELECT '═══════════════════════════════════════════════════════════';
