-- ============================================================================
-- SEMANTIC VIEW & INTERNAL MARKETPLACE: Retail Customer Churn Risk
-- ============================================================================
-- This script creates:
-- 1. A Semantic View that exposes the data product with business-friendly 
--    definitions and curated metrics
-- 2. An Internal Marketplace listing for discovery and access
--
-- Semantic Views: https://docs.snowflake.com/en/user-guide/views-semantic/overview
-- Internal Marketplace: https://docs.snowflake.com/en/user-guide/collaboration/listings/organizational/org-listing-about
-- ============================================================================

USE ROLE ACCOUNTADMIN;  -- Or appropriate role with CREATE privileges
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- PART 1: CREATE SEMANTIC VIEW
-- ============================================================================
-- Semantic Views provide a unified serving layer that:
-- - Captures business logic and taxonomy in one place
-- - Ensures consistency for all consumers (BI, ML, analysts)
-- - Enables natural language queries via Cortex Analyst
-- ============================================================================

-- First, create the base table if running dbt model hasn't created it yet
-- (This is the output from the dbt model)
-- In production, this would be created by: dbt run --select retail_customer_churn_risk

-- Create the Semantic View definition
CREATE OR REPLACE SEMANTIC VIEW retail_customer_churn_risk_sv
  COMMENT = 'Semantic view for Retail Customer Churn Risk data product - enables natural language analytics'
AS
-- ============================================================================
-- TABLES: Define the underlying data sources
-- ============================================================================
TABLES (
    -- Primary table: The churn risk data product
    churn_risk_data AS (
        SELECT *
        FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    )
    COMMENT = 'Retail customer churn risk scores with behavioral signals and recommended interventions'
    PRIMARY KEY (customer_id)
)

-- ============================================================================
-- DIMENSIONS: Business entities for slicing and filtering
-- ============================================================================
DIMENSIONS (
    -- Customer dimension
    customer AS (
        customer_id 
            COMMENT = 'Unique identifier for the retail customer'
            SYNONYMS = ('customer number', 'client id', 'cust id'),
        customer_name 
            COMMENT = 'Full name of the customer'
            SYNONYMS = ('name', 'client name'),
        customer_segment 
            COMMENT = 'Customer value segment: MASS_MARKET, MASS_AFFLUENT, AFFLUENT, HIGH_NET_WORTH'
            SYNONYMS = ('segment', 'tier', 'customer tier', 'value segment'),
        region 
            COMMENT = 'Geographic region of the customer'
            SYNONYMS = ('location', 'area', 'geography')
    ) COMMENT = 'Customer identification and classification attributes',
    
    -- Risk classification dimension
    risk_classification AS (
        risk_tier 
            COMMENT = 'Risk level: LOW (0-25), MEDIUM (26-50), HIGH (51-75), CRITICAL (76+)'
            SYNONYMS = ('risk level', 'risk category', 'churn tier'),
        primary_risk_driver 
            COMMENT = 'Main factor driving the churn risk score'
            SYNONYMS = ('risk reason', 'churn driver', 'main risk factor'),
        recommended_intervention 
            COMMENT = 'Suggested action to retain the customer'
            SYNONYMS = ('action', 'intervention', 'recommendation', 'next best action'),
        intervention_priority 
            COMMENT = 'Priority ranking: 1 (urgent) to 4 (monitor)'
            SYNONYMS = ('priority', 'urgency')
    ) COMMENT = 'Risk tier and intervention recommendations',
    
    -- Time dimension
    time AS (
        data_as_of_date 
            COMMENT = 'Business date of the source data'
            SYNONYMS = ('date', 'as of date', 'report date'),
        score_calculated_at 
            COMMENT = 'Timestamp when the risk score was calculated'
            SYNONYMS = ('calculation time', 'refresh time')
    ) COMMENT = 'Temporal attributes for the data product'
)

-- ============================================================================
-- MEASURES: Quantitative metrics for analysis
-- ============================================================================
MEASURES (
    -- Core risk metrics
    risk_metrics AS (
        churn_risk_score 
            COMMENT = 'Churn probability score from 0 (lowest risk) to 100 (highest risk)'
            SYNONYMS = ('risk score', 'churn score', 'churn probability', 'score')
            AGGREGATION = AVG,
        total_customers 
            EXPR = COUNT(DISTINCT customer_id)
            COMMENT = 'Total number of customers'
            SYNONYMS = ('customer count', 'number of customers'),
        high_risk_customers 
            EXPR = COUNT(DISTINCT CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN customer_id END)
            COMMENT = 'Count of customers with HIGH or CRITICAL risk tier'
            SYNONYMS = ('at risk customers', 'risky customers'),
        critical_risk_customers 
            EXPR = COUNT(DISTINCT CASE WHEN risk_tier = 'CRITICAL' THEN customer_id END)
            COMMENT = 'Count of customers with CRITICAL risk tier requiring urgent action'
            SYNONYMS = ('critical customers', 'urgent cases')
    ) COMMENT = 'Churn risk scoring metrics',
    
    -- Relationship metrics
    relationship_metrics AS (
        avg_tenure_months 
            EXPR = AVG(relationship_tenure_months)
            COMMENT = 'Average customer relationship length in months'
            SYNONYMS = ('average tenure', 'avg relationship length'),
        avg_products_per_customer 
            EXPR = AVG(total_products_held)
            COMMENT = 'Average number of products per customer'
            SYNONYMS = ('product penetration', 'avg products'),
        total_relationship_value 
            EXPR = SUM(total_relationship_balance)
            COMMENT = 'Sum of all customer balances in GBP'
            SYNONYMS = ('total balance', 'AUM', 'assets under management')
    ) COMMENT = 'Customer relationship depth metrics',
    
    -- Behavioral metrics
    behavioral_metrics AS (
        avg_monthly_transactions 
            EXPR = AVG(avg_monthly_transactions_3m)
            COMMENT = 'Average transaction count per customer per month'
            SYNONYMS = ('transaction frequency', 'activity level'),
        digital_engagement_avg 
            EXPR = AVG(digital_engagement_score)
            COMMENT = 'Average digital engagement score across customers'
            SYNONYMS = ('engagement score', 'digital score'),
        dormant_customer_count 
            EXPR = COUNT(DISTINCT CASE WHEN dormancy_flag = TRUE THEN customer_id END)
            COMMENT = 'Count of customers showing dormancy signals'
            SYNONYMS = ('inactive customers', 'dormant accounts')
    ) COMMENT = 'Customer behavior and engagement metrics',
    
    -- Complaint metrics
    complaint_metrics AS (
        customers_with_complaints 
            EXPR = COUNT(DISTINCT CASE WHEN complaints_last_12m > 0 THEN customer_id END)
            COMMENT = 'Count of customers who filed complaints in last 12 months'
            SYNONYMS = ('complainers', 'unhappy customers'),
        customers_with_open_complaints 
            EXPR = COUNT(DISTINCT CASE WHEN open_complaints_count > 0 THEN customer_id END)
            COMMENT = 'Count of customers with unresolved complaints'
            SYNONYMS = ('open complaint customers', 'pending complaints'),
        avg_complaints_per_customer 
            EXPR = AVG(complaints_last_12m)
            COMMENT = 'Average complaints per customer in last 12 months'
    ) COMMENT = 'Customer complaint and service issue metrics'
)

-- ============================================================================
-- FILTERS: Pre-defined filter conditions for common analyses
-- ============================================================================
FILTERS (
    high_risk_only 
        EXPR = risk_tier IN ('HIGH', 'CRITICAL')
        COMMENT = 'Filter to show only HIGH and CRITICAL risk customers',
    requires_intervention 
        EXPR = recommended_intervention != 'NO_ACTION'
        COMMENT = 'Filter to show customers requiring some intervention',
    affluent_segment 
        EXPR = customer_segment IN ('AFFLUENT', 'HIGH_NET_WORTH')
        COMMENT = 'Filter to show only affluent and high net worth customers',
    has_complaints 
        EXPR = complaints_last_12m > 0 OR open_complaints_count > 0
        COMMENT = 'Filter to show customers with complaint history'
);

-- Add comment to the semantic view
COMMENT ON SEMANTIC VIEW retail_customer_churn_risk_sv IS 
'Retail Customer Churn Risk Data Product - Semantic View for natural language analytics.
Contract Version: 1.0.0 | Owner: sarah.mitchell@bank.com | SLA: Daily refresh by 6 AM UTC';


-- ============================================================================
-- PART 2: CREATE INTERNAL MARKETPLACE LISTING
-- ============================================================================
-- The Internal Marketplace enables data discovery and controlled sharing
-- within the organization
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

-- Grant select on the semantic view
GRANT SELECT ON VIEW RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK_SV 
    TO SHARE retail_churn_risk_share;


-- Step 2b: Create the internal listing
-- Note: This requires the ACCOUNTADMIN role or CREATE LISTING privilege
CREATE OR REPLACE LISTING retail_customer_churn_risk_listing
    FOR SHARE retail_churn_risk_share
    AS $$
    title: "Retail Customer Churn Risk Data Product"
    subtitle: "AI-ready customer churn predictions with explainable risk drivers"
    description: |
      ## Overview
      The Retail Customer Churn Risk data product provides daily-refreshed 
      churn risk scores for retail banking customers, combining behavioral 
      signals, transactional patterns, and engagement data.
      
      ## Key Features
      - **Churn Risk Score**: 0-100 score indicating likelihood of churn
      - **Risk Tier Classification**: LOW, MEDIUM, HIGH, CRITICAL
      - **Explainable Risk Drivers**: Understand why customers are at risk
      - **Recommended Interventions**: Actionable next best actions
      
      ## Use Cases
      - Retention campaign targeting
      - Branch intervention prioritization
      - Executive churn KPI reporting
      - ML model feature input
      
      ## Data Contract
      - Version: 1.0.0
      - Refresh: Daily by 6 AM UTC
      - Availability SLA: 99.5%
      
      ## Access
      Contact: retail-data-support@bank.com
      
    terms_of_service: |
      This data product contains confidential customer information.
      - Only authorized roles may access
      - Do not export to external systems without approval
      - Comply with GDPR and FCA Consumer Duty requirements
      
    business_needs:
      - "Customer Retention"
      - "Risk Management"
      - "Marketing Analytics"
      - "Branch Operations"
      
    refresh_schedule: "DAILY"
    
    usage_examples:
      - title: "Find high-risk customers"
        description: "Query customers requiring immediate attention"
        code: |
          SELECT customer_id, customer_name, churn_risk_score, recommended_intervention
          FROM RETAIL_CUSTOMER_CHURN_RISK
          WHERE risk_tier = 'CRITICAL'
          ORDER BY churn_risk_score DESC
          LIMIT 100;
          
      - title: "Risk distribution by segment"
        description: "Analyze risk across customer segments"
        code: |
          SELECT 
            customer_segment,
            risk_tier,
            COUNT(*) as customer_count,
            AVG(churn_risk_score) as avg_risk_score
          FROM RETAIL_CUSTOMER_CHURN_RISK
          GROUP BY customer_segment, risk_tier
          ORDER BY customer_segment, risk_tier;
    $$;

-- Step 2c: Set listing visibility to organization
ALTER LISTING retail_customer_churn_risk_listing 
    SET VISIBILITY = 'ORGANIZATION';

-- Step 2d: Add accounts that can access (for specific sharing)
-- Replace with actual consumer account names
-- ALTER LISTING retail_customer_churn_risk_listing 
--     ADD ACCOUNTS = ('consumer_account_1', 'consumer_account_2');


-- ============================================================================
-- PART 3: GRANT ACCESS TO CONSUMING ROLES
-- ============================================================================
-- In production, create specific roles for different consumer groups
-- ============================================================================

-- Create roles for different access levels
CREATE ROLE IF NOT EXISTS retention_analyst;
CREATE ROLE IF NOT EXISTS branch_manager;
CREATE ROLE IF NOT EXISTS data_scientist;

-- Grant access to the data product
GRANT USAGE ON DATABASE RETAIL_BANKING_DB TO ROLE retention_analyst;
GRANT USAGE ON SCHEMA RETAIL_BANKING_DB.DATA_PRODUCTS TO ROLE retention_analyst;
GRANT SELECT ON TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK TO ROLE retention_analyst;
GRANT SELECT ON VIEW RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK_SV TO ROLE retention_analyst;

-- Repeat for other roles
GRANT USAGE ON DATABASE RETAIL_BANKING_DB TO ROLE branch_manager;
GRANT USAGE ON SCHEMA RETAIL_BANKING_DB.DATA_PRODUCTS TO ROLE branch_manager;
GRANT SELECT ON TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK TO ROLE branch_manager;

GRANT USAGE ON DATABASE RETAIL_BANKING_DB TO ROLE data_scientist;
GRANT USAGE ON SCHEMA RETAIL_BANKING_DB.DATA_PRODUCTS TO ROLE data_scientist;
GRANT SELECT ON TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK TO ROLE data_scientist;
GRANT SELECT ON VIEW RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK_SV TO ROLE data_scientist;


-- ============================================================================
-- PART 4: SAMPLE QUERIES FOR CONSUMERS
-- ============================================================================
-- These queries demonstrate how consumers can use the data product
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
-- 1. Semantic View created for natural language analytics
-- 2. Internal Marketplace listing published
-- 3. Access roles configured
-- 4. Sample queries provided for consumers
-- ============================================================================

