-- ============================================================================
-- STEP 1: SNOWFLAKE GIT INTEGRATION SETUP
-- ============================================================================
-- This script creates a Git integration in Snowflake to connect to the
-- GitHub repository containing the data product code samples.
--
-- Prerequisites:
--   - ACCOUNTADMIN role (or CREATE INTEGRATION privilege)
--   - GitHub Personal Access Token (for private repos) or public repo access
--
-- Repository: https://github.com/sfc-gh-skuppusamy/data-products-code-sample
-- ============================================================================

-- Set context
USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- OPTION A: PUBLIC REPOSITORY (No authentication needed)
-- ============================================================================
-- Use this if the repository is public

CREATE OR REPLACE API INTEGRATION git_api_integration_public
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-skuppusamy/')
  ENABLED = TRUE
  COMMENT = 'Git integration for Data Products FSI code samples (public repo)';

-- ============================================================================
-- OPTION B: PRIVATE REPOSITORY (Requires GitHub PAT)
-- ============================================================================
-- Use this if the repository is private or you need authenticated access
-- 
-- First, create a secret with your GitHub Personal Access Token:
-- 1. Go to GitHub → Settings → Developer settings → Personal access tokens
-- 2. Generate a token with 'repo' scope
-- 3. Replace 'your-github-pat-here' below

/*
-- Create a secret for GitHub authentication
CREATE OR REPLACE SECRET git_secret
  TYPE = password
  USERNAME = 'sfc-gh-skuppusamy'
  PASSWORD = 'your-github-pat-here'  -- Replace with your GitHub PAT
  COMMENT = 'GitHub PAT for private repo access';

-- Create API integration for private repo
CREATE OR REPLACE API INTEGRATION git_api_integration_private
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-skuppusamy/')
  ALLOWED_AUTHENTICATION_SECRETS = (git_secret)
  ENABLED = TRUE
  COMMENT = 'Git integration for Data Products FSI code samples (private repo)';
*/

-- ============================================================================
-- CREATE DATABASE AND SCHEMA FOR THE PROJECT
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

-- ============================================================================
-- CREATE GIT REPOSITORY
-- ============================================================================
-- This creates a connection to the GitHub repository

USE SCHEMA RETAIL_BANKING_DB.GOVERNANCE;

CREATE OR REPLACE GIT REPOSITORY data_products_repo
  API_INTEGRATION = git_api_integration_public
  ORIGIN = 'https://github.com/sfc-gh-skuppusamy/data-products-code-sample.git'
  COMMENT = 'Data Products for FSI code samples repository';

-- ============================================================================
-- VERIFY THE REPOSITORY CONNECTION
-- ============================================================================

-- List branches
SHOW GIT BRANCHES IN data_products_repo;

-- Fetch latest changes from remote
ALTER GIT REPOSITORY data_products_repo FETCH;

-- List files in the repository
SELECT * FROM TABLE(
  SNOWFLAKE.CORE.LIST_STAGE_CONTENTS(
    STAGE_URL => '@data_products_repo/branches/main/'
  )
);

-- ============================================================================
-- VIEW REPOSITORY CONTENTS
-- ============================================================================

-- List all files in the main branch
LS @data_products_repo/branches/main/;

-- View specific folders
LS @data_products_repo/branches/main/00_setup/;
LS @data_products_repo/branches/main/01_discover/;
LS @data_products_repo/branches/main/02_design/;
LS @data_products_repo/branches/main/03_deliver/;
LS @data_products_repo/branches/main/04_operate/;
LS @data_products_repo/branches/main/05_refine/;

-- ============================================================================
-- GRANT ACCESS TO OTHER ROLES (Optional)
-- ============================================================================

-- Grant usage on the Git repository to other roles
-- GRANT USAGE ON GIT REPOSITORY data_products_repo TO ROLE DATA_ENGINEER;
-- GRANT USAGE ON GIT REPOSITORY data_products_repo TO ROLE DATA_ANALYST;

-- ============================================================================
-- NEXT STEPS
-- ============================================================================
-- Run the following scripts in order:
--   1. 00_setup/02_run_setup_from_git.sql   - Execute all setup scripts
--   2. Or run individual scripts:
--      - 03_deliver/03a_create_sample_data.sql
--      - 03_deliver/03c_output_examples/retail_customer_churn_risk.sql
--      - etc.
-- ============================================================================

SELECT 'Git integration setup complete!' AS status,
       'Repository connected: data_products_repo' AS message,
       'Run: LS @data_products_repo/branches/main/' AS next_step;

