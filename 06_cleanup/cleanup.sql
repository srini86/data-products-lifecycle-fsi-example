-- ============================================================================
-- CLEANUP.SQL - Remove All Demo Resources
-- ============================================================================
-- This script removes all resources created by setup.sql
--
-- WARNING: This will permanently delete:
--   - Database RETAIL_BANKING_DB (and all schemas, tables, data)
--   - Warehouse DATA_PRODUCTS_WH
--   - All Streamlit apps, stages, and governance objects
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
-- STEP 1: DROP STREAMLIT APPS
-- ============================================================================

SELECT '🗑️  Step 1: Dropping Streamlit apps...' AS status;

DROP STREAMLIT IF EXISTS RETAIL_BANKING_DB.GOVERNANCE.dbt_code_generator;

SELECT '✅ Step 1 Complete: Streamlit apps dropped' AS status;


-- ============================================================================
-- STEP 2: DROP DATABASE (Cascades to all schemas, tables, stages, etc.)
-- ============================================================================

SELECT '🗑️  Step 2: Dropping database RETAIL_BANKING_DB...' AS status;

DROP DATABASE IF EXISTS RETAIL_BANKING_DB CASCADE;

SELECT '✅ Step 2 Complete: Database dropped (all schemas, tables, stages removed)' AS status;


-- ============================================================================
-- STEP 3: DROP WAREHOUSE
-- ============================================================================

SELECT '🗑️  Step 3: Dropping warehouse DATA_PRODUCTS_WH...' AS status;

DROP WAREHOUSE IF EXISTS DATA_PRODUCTS_WH;

SELECT '✅ Step 3 Complete: Warehouse dropped' AS status;


-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================

SELECT '═══════════════════════════════════════════════════════════' AS msg
UNION ALL SELECT '                    🧹 CLEANUP COMPLETE!                     '
UNION ALL SELECT '═══════════════════════════════════════════════════════════'
UNION ALL SELECT ''
UNION ALL SELECT 'The following resources have been removed:'
UNION ALL SELECT '  • Database: RETAIL_BANKING_DB'
UNION ALL SELECT '    - Schema: RAW (and all source tables)'
UNION ALL SELECT '    - Schema: DATA_PRODUCTS (and all data product tables)'
UNION ALL SELECT '    - Schema: GOVERNANCE (stages, Streamlit apps)'
UNION ALL SELECT '    - Schema: MONITORING (metrics, alerts)'
UNION ALL SELECT '  • Warehouse: DATA_PRODUCTS_WH'
UNION ALL SELECT ''
UNION ALL SELECT 'To recreate the demo environment, run:'
UNION ALL SELECT '  snowsql -f setup.sql'
UNION ALL SELECT ''
UNION ALL SELECT '═══════════════════════════════════════════════════════════';

