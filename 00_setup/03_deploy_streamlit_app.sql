-- ============================================================================
-- STEP 3: DEPLOY STREAMLIT APP FROM GIT REPOSITORY
-- ============================================================================
-- This script deploys the dbt Code Generator Streamlit app directly from
-- the Git repository. The app generates dbt code from data contracts.
--
-- Prerequisites:
--   - 01_git_integration.sql must be run first
--   - Streamlit in Snowflake must be enabled for your account
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA RAW;

-- Ensure we have latest from Git
ALTER GIT REPOSITORY GOVERNANCE.data_products_repo FETCH;

-- ============================================================================
-- CREATE THE STREAMLIT APP
-- ============================================================================
-- Deploy the app directly from the Git repository

CREATE OR REPLACE STREAMLIT dbt_code_generator
  ROOT_LOCATION = '@GOVERNANCE.data_products_repo/branches/main/03_deliver'
  MAIN_FILE = '03b_dbt_generator_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  COMMENT = 'Generates dbt code from data contracts using Cortex LLM';

-- ============================================================================
-- GRANT ACCESS
-- ============================================================================
-- Grant usage to roles that should use the app

GRANT USAGE ON STREAMLIT dbt_code_generator TO ROLE PUBLIC;

-- Or grant to specific roles:
-- GRANT USAGE ON STREAMLIT dbt_code_generator TO ROLE DATA_ENGINEER;
-- GRANT USAGE ON STREAMLIT dbt_code_generator TO ROLE DATA_ANALYST;

-- ============================================================================
-- UPLOAD DATA CONTRACT TO A STAGE (Optional)
-- ============================================================================
-- Create a stage where users can upload their data contracts

CREATE STAGE IF NOT EXISTS GOVERNANCE.data_contracts
  COMMENT = 'Stage for uploading data contract YAML files';

-- Copy the example contract from Git to the contracts stage
-- Note: This allows users to load the contract from within the app
COPY FILES 
  INTO @GOVERNANCE.data_contracts
  FROM @GOVERNANCE.data_products_repo/branches/main/02_design/
  PATTERN = '.*\.yaml';

-- List contracts available
LS @GOVERNANCE.data_contracts;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Show the Streamlit app
SHOW STREAMLITS;

-- Get the app URL
SELECT 
    'Streamlit App Deployed!' AS status,
    STREAMLIT_URL AS app_url
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE NAME = 'DBT_CODE_GENERATOR';

-- ============================================================================
-- HOW TO USE THE APP
-- ============================================================================

SELECT 
'=== How to Use the dbt Code Generator ===' AS instructions
UNION ALL SELECT ''
UNION ALL SELECT '1. Open the Streamlit app from the URL above'
UNION ALL SELECT '2. Choose input method:'
UNION ALL SELECT '   - Paste YAML directly'
UNION ALL SELECT '   - Upload a file'
UNION ALL SELECT '   - Load from stage: RETAIL_BANKING_DB.GOVERNANCE.DATA_CONTRACTS'
UNION ALL SELECT '3. Click "Generate All Outputs"'
UNION ALL SELECT '4. Download the generated files:'
UNION ALL SELECT '   - model.sql (dbt transformation)'
UNION ALL SELECT '   - schema.yml (documentation & tests)'
UNION ALL SELECT '   - masking_policies.sql (Snowflake policies)'
UNION ALL SELECT ''
UNION ALL SELECT 'Example contract file: churn_risk_data_contract.yaml';

-- ============================================================================
-- UPDATE APP FROM GIT (When code changes)
-- ============================================================================

/*
-- Fetch latest changes from Git
ALTER GIT REPOSITORY GOVERNANCE.data_products_repo FETCH;

-- The Streamlit app will automatically pick up changes since it 
-- references the Git repository location directly
*/

