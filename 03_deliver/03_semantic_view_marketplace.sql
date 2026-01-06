-- ============================================================================
-- SEMANTIC VIEW & INTERNAL MARKETPLACE: Retail Customer Churn Risk
-- ============================================================================
-- This script creates:
-- 1. A Semantic View for Cortex Analyst (natural language queries)
-- 2. An Internal Marketplace listing for discovery and access
--
-- Semantic Views: https://docs.snowflake.com/en/user-guide/views-semantic
-- Internal Marketplace: https://docs.snowflake.com/en/user-guide/collaboration/listings
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;
USE SCHEMA DATA_PRODUCTS;

-- ============================================================================
-- PART 1: CREATE SEMANTIC VIEW
-- ============================================================================
-- Semantic Views enable natural language queries via Cortex Analyst
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW retail_customer_churn_risk_sv
TABLES (
    churn_risk AS (
        SELECT *
        FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    )
    PRIMARY KEY (customer_id)
)
DIMENSIONS (
    -- Customer attributes
    customer_id
        DESCRIPTION 'Unique identifier for the retail customer'
        SYNONYMS ('customer number', 'client id', 'cust id'),
    customer_name
        DESCRIPTION 'Full name of the customer'
        SYNONYMS ('name', 'client name'),
    customer_segment
        DESCRIPTION 'Customer value segment: MASS_MARKET, MASS_AFFLUENT, AFFLUENT, HIGH_NET_WORTH'
        SYNONYMS ('segment', 'tier', 'customer tier'),
    region
        DESCRIPTION 'Geographic region of the customer'
        SYNONYMS ('location', 'area', 'geography'),
    
    -- Risk classification
    risk_tier
        DESCRIPTION 'Risk level: LOW (0-25), MEDIUM (26-50), HIGH (51-75), CRITICAL (76+)'
        SYNONYMS ('risk level', 'risk category', 'churn tier'),
    primary_risk_driver
        DESCRIPTION 'Main factor driving the churn risk score'
        SYNONYMS ('risk reason', 'churn driver', 'main risk factor'),
    recommended_intervention
        DESCRIPTION 'Suggested action to retain the customer'
        SYNONYMS ('action', 'intervention', 'recommendation', 'next best action'),
    
    -- Time
    data_as_of_date
        DESCRIPTION 'Business date of the source data'
        SYNONYMS ('date', 'as of date', 'report date')
)
MEASURES (
    -- Risk metrics
    churn_risk_score
        DESCRIPTION 'Churn probability score from 0 (lowest risk) to 100 (highest risk)'
        SYNONYMS ('risk score', 'churn score', 'churn probability')
        AGGREGATION AVG,
    
    total_customers
        EXPR COUNT(DISTINCT customer_id)
        DESCRIPTION 'Total number of customers'
        SYNONYMS ('customer count', 'number of customers'),
    
    high_risk_customers
        EXPR COUNT(DISTINCT CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN customer_id END)
        DESCRIPTION 'Count of customers with HIGH or CRITICAL risk tier'
        SYNONYMS ('at risk customers', 'risky customers'),
    
    -- Relationship metrics
    total_relationship_value
        EXPR SUM(total_relationship_balance)
        DESCRIPTION 'Sum of all customer balances in GBP'
        SYNONYMS ('total balance', 'AUM', 'assets under management'),
    
    avg_tenure_months
        EXPR AVG(relationship_tenure_months)
        DESCRIPTION 'Average customer relationship length in months'
        SYNONYMS ('average tenure', 'avg relationship length'),
    
    -- Behavioral metrics
    avg_digital_engagement
        EXPR AVG(digital_engagement_score)
        DESCRIPTION 'Average digital engagement score across customers'
        SYNONYMS ('engagement score', 'digital score'),
    
    dormant_customers
        EXPR COUNT(DISTINCT CASE WHEN dormancy_flag = TRUE THEN customer_id END)
        DESCRIPTION 'Count of customers showing dormancy signals'
        SYNONYMS ('inactive customers', 'dormant accounts')
)
FILTERS (
    high_risk_only
        EXPR risk_tier IN ('HIGH', 'CRITICAL')
        DESCRIPTION 'Filter to show only HIGH and CRITICAL risk customers',
    
    requires_intervention
        EXPR recommended_intervention != 'NO_ACTION'
        DESCRIPTION 'Filter to show customers requiring some intervention',
    
    affluent_segment
        EXPR customer_segment IN ('AFFLUENT', 'HIGH_NET_WORTH')
        DESCRIPTION 'Filter to show only affluent and high net worth customers'
);

-- Add comment to the semantic view
COMMENT ON SEMANTIC VIEW retail_customer_churn_risk_sv IS 
'Retail Customer Churn Risk Data Product - Semantic View for Cortex Analyst.
Contract Version: 1.0.0 | Owner: sarah.mitchell@bank.com | SLA: Daily refresh by 6 AM UTC';


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
-- ============================================================================
