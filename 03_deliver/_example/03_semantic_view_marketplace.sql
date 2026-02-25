-- ============================================================================
-- SEMANTIC VIEW & INTERNAL MARKETPLACE: Retail Customer Churn Risk
-- ============================================================================
-- This script creates:
-- 1. A Semantic View for Cortex Analyst (natural language queries)
-- 2. An Internal Marketplace listing for discovery and access
--
-- Reference: https://github.com/NickAkincilar/Snowflake_AI_DEMO
-- Docs: https://docs.snowflake.com/en/user-guide/views-semantic
-- ============================================================================

-- NOTE: Replace ACCOUNTADMIN with a least-privilege role in production
USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- PART 1: CREATE SEMANTIC VIEW
-- ============================================================================
-- Semantic Views enable natural language queries via Cortex Analyst
-- Syntax from: https://github.com/NickAkincilar/Snowflake_AI_DEMO/blob/main/sql_scripts/demo_setup.sql
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW retail_customer_churn_risk_sv
TABLES (
    churn AS DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK PRIMARY KEY (customer_id)
  )
DIMENSIONS (
    -- Customer attributes
    churn.customer_id AS customer_id,
    churn.customer_name AS customer_name,
    churn.customer_segment AS customer_segment,
    churn.region AS region,
    
    -- Risk classification
    churn.risk_tier AS risk_tier,
    churn.primary_risk_driver AS primary_risk_driver,
    churn.recommended_intervention AS recommended_intervention,
    churn.intervention_priority AS intervention_priority,
    
    -- Trends
    churn.transaction_trend AS transaction_trend,
    churn.balance_trend AS balance_trend,
    
    -- Flags
    churn.declining_balance_flag AS declining_balance_flag,
    churn.reduced_activity_flag AS reduced_activity_flag,
    churn.low_engagement_flag AS low_engagement_flag,
    churn.complaint_flag AS complaint_flag,
    churn.dormancy_flag AS dormancy_flag,
    churn.has_unresolved_complaint AS has_unresolved_complaint,
    churn.mobile_app_active AS mobile_app_active,
    
    -- Numeric fields (as dimensions for filtering/grouping)
    churn.churn_risk_score AS churn_risk_score,
    churn.total_relationship_balance AS total_relationship_balance,
    churn.relationship_tenure_months AS relationship_tenure_months,
    churn.digital_engagement_score AS digital_engagement_score,
    churn.open_complaints_count AS open_complaints_count,
    
    -- Time
    churn.data_as_of_date AS data_as_of_date,
    churn.model_version AS model_version
  )
  METRICS (
    -- Note: Semantic View metrics currently support COUNT reliably
    -- AVG/SUM may not be supported depending on Snowflake version
    customer_count AS COUNT(churn.customer_id)
);

-- Add comment to the semantic view
COMMENT ON SEMANTIC VIEW retail_customer_churn_risk_sv IS 
'Retail Customer Churn Risk Data Product - Semantic View for Cortex Analyst.
Contract Version: 1.0.0 | Owner: alex.morgan@bank.com | SLA: Daily refresh by 6 AM UTC

Example questions:
- What is the average churn risk score by customer segment?
- Show me high risk customers in the South East region
- Which regions have the most critical risk customers?
- What is the total balance at risk for customers with complaints?';

-- Verify semantic view was created
SHOW SEMANTIC VIEWS LIKE 'retail_customer_churn_risk_sv';


-- ============================================================================
-- PART 2: CREATE INTERNAL MARKETPLACE LISTING
-- ============================================================================

-- Step 2a: Create a share for the data product
CREATE OR REPLACE SHARE retail_churn_risk_share
    COMMENT = 'Internal share for Retail Customer Churn Risk data product';

-- Grant usage on database and schema
GRANT USAGE ON DATABASE RETAIL_BANKING_DB TO SHARE retail_churn_risk_share;
GRANT USAGE ON SCHEMA RETAIL_BANKING_DB.DATA_PRODUCTS TO SHARE retail_churn_risk_share;

-- Grant select on the data product table
GRANT SELECT ON TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK 
    TO SHARE retail_churn_risk_share;

-- Grant reference on the semantic view
GRANT REFERENCE_USAGE ON DATABASE RETAIL_BANKING_DB TO SHARE retail_churn_risk_share;


-- Step 2b: Create the internal listing
-- ╔════════════════════════════════════════════════════════════════════════════╗
-- ║ UPDATE THESE VALUES FOR YOUR ENVIRONMENT:                                   ║
-- ║   - YOUR_ACCOUNT_NAME: Your Snowflake account identifier                   ║
-- ║   - your.email@company.com: Your email for approver/support contacts       ║
-- ╚════════════════════════════════════════════════════════════════════════════╝
-- NOTE: CREATE LISTING does not support OR REPLACE. Drop first if it exists.
-- DROP LISTING IF EXISTS retail_customer_churn_risk;  -- Only works for unpublished listings

CREATE LISTING IF NOT EXISTS retail_customer_churn_risk
  FOR SHARE retail_churn_risk_share
  AS
$$
title: Retail Customer Churn Risk
description: |
  Daily churn risk scores for retail banking customers.
  Features: Risk Score (0-100), Risk Tier, Primary Risk Driver, Recommended Intervention.
organization_profile: INTERNAL
organization_targets:
  access:
  - account: YOUR_ACCOUNT_NAME
  discovery:
  - account: YOUR_ACCOUNT_NAME
locations:
  access_regions:
  - name: ALL
approver_contact: your.email@company.com
support_contact: your.email@company.com
$$
DISTRIBUTION = ORGANIZATION;


-- ============================================================================
-- PART 3: GRANT ACCESS TO CONSUMING ROLES
-- ============================================================================

-- Create roles for different access levels
CREATE ROLE IF NOT EXISTS retention_analyst;
CREATE ROLE IF NOT EXISTS branch_manager;
CREATE ROLE IF NOT EXISTS data_scientist;

-- Grant access to the data product
GRANT USAGE ON DATABASE RETAIL_BANKING_DB TO ROLE retention_analyst;
GRANT USAGE ON SCHEMA RETAIL_BANKING_DB.DATA_PRODUCTS TO ROLE retention_analyst;
GRANT SELECT ON TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK TO ROLE retention_analyst;

GRANT USAGE ON DATABASE RETAIL_BANKING_DB TO ROLE branch_manager;
GRANT USAGE ON SCHEMA RETAIL_BANKING_DB.DATA_PRODUCTS TO ROLE branch_manager;
GRANT SELECT ON TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK TO ROLE branch_manager;

GRANT USAGE ON DATABASE RETAIL_BANKING_DB TO ROLE data_scientist;
GRANT USAGE ON SCHEMA RETAIL_BANKING_DB.DATA_PRODUCTS TO ROLE data_scientist;
GRANT SELECT ON TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK TO ROLE data_scientist;


-- ============================================================================
-- PART 4: SAMPLE QUERIES FOR CONSUMERS
-- ============================================================================

-- Query 1: High-risk customers requiring immediate attention
SELECT 
    customer_id,
    customer_name,
    customer_segment,
    churn_risk_score,
    risk_tier,
    primary_risk_driver,
    recommended_intervention
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
WHERE risk_tier = 'CRITICAL'
ORDER BY churn_risk_score DESC
LIMIT 50;

-- Query 2: Risk distribution dashboard
SELECT 
    risk_tier,
    COUNT(*) AS customer_count,
    ROUND(AVG(churn_risk_score), 1) AS avg_risk_score,
    ROUND(SUM(total_relationship_balance), 0) AS total_balance_at_risk,
    ROUND(AVG(relationship_tenure_months), 1) AS avg_tenure_months
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
GROUP BY risk_tier
ORDER BY 
    CASE risk_tier 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        ELSE 4 
    END;

-- Query 3: Risk drivers analysis
SELECT 
    primary_risk_driver,
    COUNT(*) AS customer_count,
    ROUND(AVG(churn_risk_score), 1) AS avg_risk_score,
    SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS high_risk_count
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
WHERE primary_risk_driver != 'NONE'
GROUP BY primary_risk_driver
ORDER BY customer_count DESC;

-- Query 4: Intervention queue for retention team
SELECT 
    customer_id,
    customer_name,
    region,
    churn_risk_score,
    recommended_intervention,
    primary_risk_driver,
    PARSE_JSON(risk_drivers_json) AS risk_details
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
WHERE recommended_intervention != 'NO_ACTION'
ORDER BY intervention_priority, churn_risk_score DESC;


-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================
-- Summary:
-- 1. Semantic View created for Cortex Analyst
-- 2. Internal Marketplace listing published
-- 3. Access roles configured
-- 4. Sample queries provided for consumers
--
-- Use Cortex Analyst to ask questions like:
-- "What is the average churn risk by segment?"
-- "Show me critical risk customers in London"
-- "Which risk driver affects the most customers?"
-- ============================================================================
