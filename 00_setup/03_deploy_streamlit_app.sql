-- ============================================================================
-- DEPLOY STREAMLIT APP: dbt Code Generator
-- ============================================================================
-- This script:
--   1. Creates stages for file uploads
--   2. Provides upload instructions for data contract & Streamlit app
--   3. Deploys the Streamlit app from the stage
--
-- Prerequisites:
--   - ACCOUNTADMIN role
--   - Streamlit in Snowflake enabled for your account
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- STEP 1: CREATE DATABASE AND SCHEMAS
-- ============================================================================

CREATE DATABASE IF NOT EXISTS RETAIL_BANKING_DB
  COMMENT = 'Database for Retail Banking Data Products';

USE DATABASE RETAIL_BANKING_DB;

CREATE SCHEMA IF NOT EXISTS RAW
  COMMENT = 'Raw source data from operational systems';

CREATE SCHEMA IF NOT EXISTS DATA_PRODUCTS
  COMMENT = 'Governed data products for consumption';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE
  COMMENT = 'Data contracts, policies, and governance artifacts';

USE SCHEMA GOVERNANCE;

-- ============================================================================
-- STEP 2: CREATE STAGES FOR FILE UPLOADS
-- ============================================================================

-- Stage for data contracts (YAML files)
CREATE STAGE IF NOT EXISTS data_contracts
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for uploading data contract YAML files';

-- Stage for Streamlit app files
CREATE STAGE IF NOT EXISTS streamlit_apps
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for Streamlit application files';

SELECT 'Stages created!' AS status;

-- ============================================================================
-- STEP 3: UPLOAD FILES TO STAGES
-- ============================================================================
-- Choose ONE of the following methods:

-- -----------------------------------------------------------------------------
-- OPTION A: Using SnowSQL (Command Line)
-- -----------------------------------------------------------------------------
-- Run these commands from your terminal:
--
-- # Navigate to the cloned repo
-- cd /path/to/data-products-code-sample
--
-- # Connect to Snowflake
-- snowsql -a <account> -u <username>
--
-- # Upload data contract
-- PUT file://02_design/churn_risk_data_contract.yaml 
--     @RETAIL_BANKING_DB.GOVERNANCE.data_contracts 
--     AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
--
-- # Upload Streamlit app
-- PUT file://03_deliver/03b_dbt_generator_app.py 
--     @RETAIL_BANKING_DB.GOVERNANCE.streamlit_apps 
--     AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- -----------------------------------------------------------------------------
-- OPTION B: Using Snowsight Web UI
-- -----------------------------------------------------------------------------
-- 1. Go to: Data → Databases → RETAIL_BANKING_DB → GOVERNANCE → Stages
-- 2. Click on "DATA_CONTRACTS" stage → "+ Files" → Upload:
--    - 02_design/churn_risk_data_contract.yaml
-- 3. Click on "STREAMLIT_APPS" stage → "+ Files" → Upload:
--    - 03_deliver/03b_dbt_generator_app.py

-- ============================================================================
-- STEP 4: VERIFY FILE UPLOADS
-- ============================================================================
-- Run these after uploading files to confirm they're there:

SELECT '=== Verify Uploads ===' AS step;

-- Check data contracts stage
LS @data_contracts;

-- Check streamlit apps stage  
LS @streamlit_apps;

-- ============================================================================
-- STEP 5: CREATE THE STREAMLIT APP
-- ============================================================================
-- Run this AFTER uploading 03b_dbt_generator_app.py to the streamlit_apps stage

CREATE OR REPLACE STREAMLIT dbt_code_generator
  ROOT_LOCATION = '@RETAIL_BANKING_DB.GOVERNANCE.streamlit_apps'
  MAIN_FILE = '03b_dbt_generator_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  COMMENT = 'Generates dbt code from data contracts using Cortex LLM';

-- Grant access
GRANT USAGE ON STREAMLIT dbt_code_generator TO ROLE PUBLIC;

-- ============================================================================
-- STEP 6: VERIFY DEPLOYMENT
-- ============================================================================

SHOW STREAMLITS IN SCHEMA GOVERNANCE;

-- Get the app URL
SELECT 
    name,
    owner,
    url_id,
    'https://app.snowflake.com/' || CURRENT_ORGANIZATION_NAME() || '/' || CURRENT_ACCOUNT_NAME() || '/#/streamlit-apps/' || url_id AS app_url
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE name = 'DBT_CODE_GENERATOR';

-- ============================================================================
-- HOW TO USE THE APP
-- ============================================================================

SELECT '=== How to Use the dbt Code Generator ===' AS instructions
UNION ALL SELECT ''
UNION ALL SELECT '1. Open the Streamlit app URL from above'
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
UNION ALL SELECT 'Example contract: churn_risk_data_contract.yaml';

-- ============================================================================
-- QUICK REFERENCE: SNOWSQL UPLOAD COMMANDS
-- ============================================================================
/*
-- Connect to Snowflake
snowsql -a <your_account> -u <your_username>

-- Set context
USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA GOVERNANCE;

-- Upload files (adjust paths to your local repo)
PUT file://02_design/churn_risk_data_contract.yaml @data_contracts AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://03_deliver/03b_dbt_generator_app.py @streamlit_apps AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Verify
LS @data_contracts;
LS @streamlit_apps;
*/
