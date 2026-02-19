-- ============================================================================
-- Masking Policies for Retail Customer Churn Risk Data Product
-- Generated from data contract: retail-customer-churn-risk v1.0.0
-- ============================================================================

USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- CUSTOMER_NAME_MASK
-- Masks customer name for unauthorized users
-- Authorized roles see full value, others see first character + asterisks
-- ============================================================================

CREATE OR REPLACE MASKING POLICY CUSTOMER_NAME_MASK AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN IS_ROLE_IN_SESSION('RETENTION_ANALYST') THEN val
        WHEN IS_ROLE_IN_SESSION('BRANCH_MANAGER') THEN val
        WHEN IS_ROLE_IN_SESSION('CUSTOMER_ANALYTICS') THEN val
        WHEN IS_ROLE_IN_SESSION('COMPLIANCE_OFFICER') THEN val
        WHEN IS_ROLE_IN_SESSION('DATA_SCIENCE_TEAM') THEN val
        WHEN IS_ROLE_IN_SESSION('SYSADMIN') THEN val
        WHEN IS_ROLE_IN_SESSION('ACCOUNTADMIN') THEN val
        ELSE LEFT(val, 1) || '****'
    END;

COMMENT ON MASKING POLICY CUSTOMER_NAME_MASK IS 
    'Masks customer name - shows full value to authorized roles, masked to others';

-- ============================================================================
-- Apply masking policy to the data product table
-- ============================================================================

ALTER TABLE IF EXISTS RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    MODIFY COLUMN customer_name
    SET MASKING POLICY CUSTOMER_NAME_MASK;

-- ============================================================================
-- Verification queries
-- ============================================================================

-- Check policy is applied
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
--     POLICY_NAME => 'CUSTOMER_NAME_MASK',
--     POLICY_KIND => 'MASKING_POLICY'
-- ));

-- Test masking (run as different roles to verify)
-- SELECT customer_id, customer_name, customer_segment 
-- FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK 
-- LIMIT 5;
