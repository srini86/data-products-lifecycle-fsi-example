-- ============================================================================
-- STEP 1: SNOWFLAKE GIT INTEGRATION SETUP
-- ============================================================================
-- This script creates a Git integration in Snowflake to connect to the
-- GitHub repository containing the data product code samples.
--
-- Prerequisites:
--   - ACCOUNTADMIN role (or CREATE INTEGRATION privilege)
--   - GitHub Personal Access Token (for private repos)
--
-- Repository: https://github.com/sfc-gh-skuppusamy/data-products-code-sample
-- ============================================================================

-- Set context
USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- CREATE DATABASE AND SCHEMA FIRST
-- ============================================================================

CREATE DATABASE IF NOT EXISTS RETAIL_BANKING_DB
  COMMENT = 'Database for Retail Banking Data Products';

CREATE SCHEMA IF NOT EXISTS RETAIL_BANKING_DB.RAW
  COMMENT = 'Raw source data from operational systems';

CREATE SCHEMA IF NOT EXISTS RETAIL_BANKING_DB.DATA_PRODUCTS
  COMMENT = 'Governed data products for consumption';

CREATE SCHEMA IF NOT EXISTS RETAIL_BANKING_DB.MONITORING
  COMMENT = 'Data quality and observability';

CREATE SCHEMA IF NOT EXISTS RETAIL_BANKING_DB.GOVERNANCE
  COMMENT = 'Git repos, contracts, and governance artifacts';

USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA GOVERNANCE;

-- ============================================================================
-- STEP A: CREATE SECRET FOR GITHUB AUTHENTICATION
-- ============================================================================
-- For private repositories, you need a GitHub Personal Access Token (PAT)
-- 
-- To create a PAT:
-- 1. Go to GitHub → Settings → Developer settings → Personal access tokens
-- 2. Click "Generate new token (classic)"
-- 3. Select scope: "repo" (full control of private repositories)
-- 4. Copy the token and paste below
--
-- IMPORTANT: Replace 'YOUR_GITHUB_PAT_HERE' with your actual token
-- ============================================================================

CREATE OR REPLACE SECRET git_secret
  TYPE = password
  USERNAME = 'sfc-gh-skuppusamy'
  PASSWORD = 'YOUR_GITHUB_PAT_HERE'  -- <-- REPLACE THIS WITH YOUR PAT
  COMMENT = 'GitHub PAT for private repo access';

-- ============================================================================
-- STEP B: CREATE API INTEGRATION
-- ============================================================================
-- This integration allows Snowflake to connect to GitHub

CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-skuppusamy/')
  ALLOWED_AUTHENTICATION_SECRETS = (git_secret)
  ENABLED = TRUE
  COMMENT = 'Git integration for Data Products FSI code samples';

-- ============================================================================
-- STEP C: CREATE GIT REPOSITORY
-- ============================================================================
-- This creates a connection to the GitHub repository

CREATE OR REPLACE GIT REPOSITORY data_products_repo
  API_INTEGRATION = git_api_integration
  GIT_CREDENTIALS = git_secret
  ORIGIN = 'https://github.com/sfc-gh-skuppusamy/data-products-code-sample.git'
  COMMENT = 'Data Products for FSI code samples repository';

-- ============================================================================
-- STEP D: FETCH AND VERIFY
-- ============================================================================

-- Fetch latest changes from remote
ALTER GIT REPOSITORY data_products_repo FETCH;

-- List branches
SHOW GIT BRANCHES IN data_products_repo;

-- List files in the repository
LS @data_products_repo/branches/main/;

-- ============================================================================
-- VIEW REPOSITORY CONTENTS
-- ============================================================================

-- View specific folders
LS @data_products_repo/branches/main/00_setup/;
LS @data_products_repo/branches/main/01_discover/;
LS @data_products_repo/branches/main/02_design/;
LS @data_products_repo/branches/main/03_deliver/;

-- ============================================================================
-- TROUBLESHOOTING
-- ============================================================================
/*
If you get "Operation 'clone' is not authorized":

1. Make sure the secret has the correct PAT:
   ALTER SECRET git_secret SET PASSWORD = 'your-new-pat';

2. Make sure the PAT has 'repo' scope in GitHub

3. Verify the integration references the secret:
   DESCRIBE API INTEGRATION git_api_integration;

4. Check network policies allow GitHub access:
   SHOW NETWORK POLICIES;

5. Try recreating in order: secret → integration → repository
*/

-- ============================================================================
-- CLEANUP (if needed to start over)
-- ============================================================================
/*
DROP GIT REPOSITORY IF EXISTS data_products_repo;
DROP API INTEGRATION IF EXISTS git_api_integration;
DROP SECRET IF EXISTS git_secret;
*/

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================

SELECT 'Git integration setup complete!' AS status,
       'Repository connected: data_products_repo' AS message,
       'Run: LS @data_products_repo/branches/main/' AS next_step;
