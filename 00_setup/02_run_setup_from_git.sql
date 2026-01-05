-- ============================================================================
-- STEP 2: RUN COMPLETE SETUP FROM GIT REPOSITORY
-- ============================================================================
-- This script runs all setup scripts directly from the Git repository.
-- Prerequisites: 01_git_integration.sql must be run first
--
-- Execution order:
--   1. Create sample data (source tables)
--   2. Create data product table
--   3. Apply masking policies
--   4. Run business rules tests
--   5. Create semantic view
--   6. Set up monitoring
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;

-- Ensure we have latest from Git
ALTER GIT REPOSITORY GOVERNANCE.data_products_repo FETCH;

-- ============================================================================
-- STEP 2.1: CREATE SAMPLE DATA
-- ============================================================================
-- This creates the source tables with realistic sample data

SELECT '========================================' AS step;
SELECT 'STEP 2.1: Creating sample data...' AS status;
SELECT '========================================' AS step;

EXECUTE IMMEDIATE FROM @GOVERNANCE.data_products_repo/branches/main/03_deliver/03a_create_sample_data.sql;

-- Verify sample data
SELECT 'Source tables created:' AS status;
SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM RAW.CUSTOMERS
UNION ALL SELECT 'ACCOUNTS', COUNT(*) FROM RAW.ACCOUNTS
UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM RAW.TRANSACTIONS
UNION ALL SELECT 'DIGITAL_ENGAGEMENT', COUNT(*) FROM RAW.DIGITAL_ENGAGEMENT
UNION ALL SELECT 'COMPLAINTS', COUNT(*) FROM RAW.COMPLAINTS;

-- ============================================================================
-- STEP 2.2: CREATE DATA PRODUCT TABLE
-- ============================================================================
-- Run the dbt model SQL to create the churn risk data product

SELECT '========================================' AS step;
SELECT 'STEP 2.2: Creating data product...' AS status;
SELECT '========================================' AS step;

USE SCHEMA DATA_PRODUCTS;

-- The dbt model file uses source() refs, so we'll create as a table directly
-- First, read and execute the model
EXECUTE IMMEDIATE FROM @GOVERNANCE.data_products_repo/branches/main/03_deliver/03c_output_examples/retail_customer_churn_risk.sql;

-- Verify data product
SELECT 'Data product created:' AS status;
SELECT 
    COUNT(*) AS total_customers,
    COUNT(CASE WHEN risk_tier = 'LOW' THEN 1 END) AS low_risk,
    COUNT(CASE WHEN risk_tier = 'MEDIUM' THEN 1 END) AS medium_risk,
    COUNT(CASE WHEN risk_tier = 'HIGH' THEN 1 END) AS high_risk,
    COUNT(CASE WHEN risk_tier = 'CRITICAL' THEN 1 END) AS critical_risk
FROM RETAIL_CUSTOMER_CHURN_RISK;

-- ============================================================================
-- STEP 2.3: APPLY MASKING POLICIES
-- ============================================================================
-- Create and apply masking policies for PII protection

SELECT '========================================' AS step;
SELECT 'STEP 2.3: Applying masking policies...' AS status;
SELECT '========================================' AS step;

EXECUTE IMMEDIATE FROM @GOVERNANCE.data_products_repo/branches/main/03_deliver/03c_output_examples/masking_policies.sql;

-- Verify masking policy
SELECT 'Masking policies applied:' AS status;
SHOW MASKING POLICIES IN SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- STEP 2.4: RUN BUSINESS RULES TESTS
-- ============================================================================
-- Validate data quality against business rules

SELECT '========================================' AS step;
SELECT 'STEP 2.4: Running business rules tests...' AS status;
SELECT '========================================' AS step;

EXECUTE IMMEDIATE FROM @GOVERNANCE.data_products_repo/branches/main/03_deliver/03c_output_examples/business_rules_tests.sql;

-- ============================================================================
-- STEP 2.5: CREATE SEMANTIC VIEW (Optional - requires Enterprise)
-- ============================================================================
-- Uncomment if you have Semantic Views enabled

/*
SELECT '========================================' AS step;
SELECT 'STEP 2.5: Creating semantic view...' AS status;
SELECT '========================================' AS step;

EXECUTE IMMEDIATE FROM @GOVERNANCE.data_products_repo/branches/main/03_deliver/03d_semantic_view_marketplace.sql;
*/

-- ============================================================================
-- STEP 2.6: SET UP MONITORING
-- ============================================================================
-- Create monitoring views, tasks, and alerts

SELECT '========================================' AS step;
SELECT 'STEP 2.6: Setting up monitoring...' AS status;
SELECT '========================================' AS step;

EXECUTE IMMEDIATE FROM @GOVERNANCE.data_products_repo/branches/main/04_operate/monitoring_observability.sql;

-- ============================================================================
-- SETUP COMPLETE - SUMMARY
-- ============================================================================

SELECT '========================================' AS step;
SELECT '✅ SETUP COMPLETE!' AS status;
SELECT '========================================' AS step;

-- Summary of what was created
SELECT 
    'RETAIL_BANKING_DB' AS database_name,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'RAW') AS raw_tables,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'DATA_PRODUCTS') AS data_product_tables,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'MONITORING') AS monitoring_objects;

-- Quick data product preview
SELECT 'Sample data product records:' AS status;
SELECT 
    customer_id,
    customer_name,
    customer_segment,
    churn_risk_score,
    risk_tier,
    primary_risk_driver,
    recommended_intervention
FROM DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
WHERE risk_tier IN ('HIGH', 'CRITICAL')
ORDER BY churn_risk_score DESC
LIMIT 10;

-- ============================================================================
-- USEFUL QUERIES
-- ============================================================================

/*
-- Query the data product
SELECT * FROM DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK LIMIT 100;

-- Check risk distribution
SELECT risk_tier, COUNT(*) AS count, ROUND(AVG(churn_risk_score), 1) AS avg_score
FROM DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
GROUP BY risk_tier
ORDER BY avg_score DESC;

-- Check monitoring health
SELECT * FROM MONITORING.data_product_health_summary;

-- View the data contract (from Git)
SELECT $1 FROM @GOVERNANCE.data_products_repo/branches/main/02_design/churn_risk_data_contract.yaml
(FILE_FORMAT => (TYPE = 'CSV' FIELD_DELIMITER = NONE RECORD_DELIMITER = NONE));

-- Refresh from Git
ALTER GIT REPOSITORY GOVERNANCE.data_products_repo FETCH;
*/

