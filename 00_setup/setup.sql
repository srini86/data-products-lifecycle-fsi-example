-- ============================================================================
-- SETUP.SQL - One-Click Setup for Data Products Code Sample
-- ============================================================================
-- This script sets up everything you need to run the demo:
--   1. Database, schemas, warehouse
--   2. Sample data (5 source tables with realistic FSI data)
--   3. Stage for data contracts
--   4. Streamlit dbt Generator app (embedded inline - no file upload needed!)
--
-- PREREQUISITES:
--   - Snowflake account with ACCOUNTADMIN role
--
-- USAGE (works in Snowsight - no SnowSQL needed!):
--   Copy and run this entire script in Snowsight
--
-- DATA VOLUMES:
--   - ~1,000 customers across 4 segments
--   - ~2,500 accounts (current, savings, credit, loans, ISAs)
--   - ~25,000 transactions over 6 months
--   - ~1,000 digital engagement records
--   - ~200 complaints
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- STEP 1: CREATE DATABASE, SCHEMAS, AND WAREHOUSE
-- ============================================================================

CREATE DATABASE IF NOT EXISTS RETAIL_BANKING_DB
    COMMENT = 'Database for Retail Banking Data Products Demo';

USE DATABASE RETAIL_BANKING_DB;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw source data from operational systems';
CREATE SCHEMA IF NOT EXISTS DATA_PRODUCTS
    COMMENT = 'Governed data products for consumption';
CREATE SCHEMA IF NOT EXISTS GOVERNANCE
    COMMENT = 'Data contracts, policies, and governance artifacts';
CREATE SCHEMA IF NOT EXISTS MONITORING
    COMMENT = 'Monitoring, metrics, and observability';

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS DATA_PRODUCTS_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dedicated warehouse for Retail Banking Data Products pipeline';

USE WAREHOUSE DATA_PRODUCTS_WH;

SELECT '✅ Step 1 Complete: Database, schemas, and warehouse created' AS status;


-- ============================================================================
-- STEP 2: CREATE STAGE FOR DATA CONTRACTS
-- ============================================================================

USE SCHEMA GOVERNANCE;

-- Stage for data contracts (YAML files)
-- Users can upload contract files here for the Streamlit app to load
CREATE STAGE IF NOT EXISTS data_contracts
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for data contract YAML files';

SELECT '✅ Step 2 Complete: Data contracts stage created' AS status;


-- ============================================================================
-- STEP 3: CREATE SOURCE TABLES
-- ============================================================================

USE SCHEMA RAW;

-- ----------------------------------------------------------------------
-- CUSTOMERS TABLE - Core customer demographics and profile
-- ----------------------------------------------------------------------
CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id         VARCHAR(50) PRIMARY KEY,
    customer_name       VARCHAR(200) NOT NULL,
    email               VARCHAR(200),
    phone               VARCHAR(20),
    date_of_birth       DATE,
    customer_segment    VARCHAR(50) NOT NULL,
    region              VARCHAR(100) NOT NULL,
    onboarding_channel  VARCHAR(50),
    onboarding_date     DATE NOT NULL,
    kyc_status          VARCHAR(20) DEFAULT 'VERIFIED',
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------
-- ACCOUNTS TABLE - Customer accounts and products
-- ----------------------------------------------------------------------
CREATE OR REPLACE TABLE ACCOUNTS (
    account_id          VARCHAR(50) PRIMARY KEY,
    customer_id         VARCHAR(50) NOT NULL REFERENCES CUSTOMERS(customer_id),
    account_type        VARCHAR(50) NOT NULL,
    product_name        VARCHAR(100) NOT NULL,
    account_status      VARCHAR(20) NOT NULL,
    opened_date         DATE NOT NULL,
    closed_date         DATE,
    current_balance     NUMBER(15,2) DEFAULT 0,
    available_balance   NUMBER(15,2) DEFAULT 0,
    overdraft_limit     NUMBER(15,2) DEFAULT 0,
    interest_rate       NUMBER(5,4),
    branch_code         VARCHAR(20),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------
-- TRANSACTIONS TABLE - Account transaction history
-- ----------------------------------------------------------------------
CREATE OR REPLACE TABLE TRANSACTIONS (
    txn_id              VARCHAR(50) PRIMARY KEY,
    account_id          VARCHAR(50) NOT NULL REFERENCES ACCOUNTS(account_id),
    txn_date            DATE NOT NULL,
    txn_timestamp       TIMESTAMP_NTZ NOT NULL,
    txn_type            VARCHAR(50) NOT NULL,
    txn_category        VARCHAR(50),
    amount              NUMBER(15,2) NOT NULL,
    balance_after       NUMBER(15,2),
    channel             VARCHAR(50),
    merchant_category   VARCHAR(100),
    description         VARCHAR(500),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------
-- DIGITAL_ENGAGEMENT TABLE - Mobile app and online banking activity
-- ----------------------------------------------------------------------
CREATE OR REPLACE TABLE DIGITAL_ENGAGEMENT (
    engagement_id       VARCHAR(50) PRIMARY KEY,
    customer_id         VARCHAR(50) NOT NULL REFERENCES CUSTOMERS(customer_id),
    measurement_date    DATE NOT NULL,
    login_count_30d     INTEGER DEFAULT 0,
    mobile_app_active   BOOLEAN DEFAULT FALSE,
    online_banking_active BOOLEAN DEFAULT FALSE,
    last_login_date     DATE,
    last_login_channel  VARCHAR(50),
    session_count_30d   INTEGER DEFAULT 0,
    avg_session_minutes NUMBER(5,1) DEFAULT 0,
    features_used_count INTEGER DEFAULT 0,
    push_notifications_enabled BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UNIQUE (customer_id, measurement_date)
);

-- ----------------------------------------------------------------------
-- COMPLAINTS TABLE - Customer complaints and service issues
-- ----------------------------------------------------------------------
CREATE OR REPLACE TABLE COMPLAINTS (
    complaint_id        VARCHAR(50) PRIMARY KEY,
    customer_id         VARCHAR(50) NOT NULL REFERENCES CUSTOMERS(customer_id),
    complaint_date      DATE NOT NULL,
    category            VARCHAR(100) NOT NULL,
    subcategory         VARCHAR(100),
    channel             VARCHAR(50),
    severity            VARCHAR(20) NOT NULL,
    status              VARCHAR(20) NOT NULL,
    resolution_date     DATE,
    resolution_type     VARCHAR(50),
    escalated           BOOLEAN DEFAULT FALSE,
    compensation_amount NUMBER(10,2),
    root_cause          VARCHAR(200),
    description         VARCHAR(1000),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

SELECT '✅ Step 3a Complete: Source tables created' AS status;


-- ============================================================================
-- STEP 4: POPULATE SAMPLE DATA
-- ============================================================================

-- Helper sequences for ID generation
CREATE OR REPLACE SEQUENCE customer_seq START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE account_seq START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE txn_seq START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE engagement_seq START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE complaint_seq START = 1 INCREMENT = 1;

-- ----------------------------------------------------------------------
-- POPULATE CUSTOMERS (~1,000 retail customers)
-- ----------------------------------------------------------------------
INSERT INTO CUSTOMERS (
    customer_id, customer_name, email, phone, date_of_birth,
    customer_segment, region, onboarding_channel, onboarding_date, kyc_status
)
SELECT 
    'CUST-' || LPAD(customer_seq.NEXTVAL::VARCHAR, 6, '0') AS customer_id,
    
    -- Generate realistic names
    ARRAY_CONSTRUCT(
        'James', 'Emma', 'Oliver', 'Sophia', 'William', 'Ava', 'Henry', 'Isabella',
        'Alexander', 'Mia', 'Benjamin', 'Charlotte', 'Lucas', 'Amelia', 'Mason',
        'Harper', 'Ethan', 'Evelyn', 'Daniel', 'Abigail', 'Matthew', 'Emily',
        'Aiden', 'Elizabeth', 'Joseph', 'Sofia', 'Samuel', 'Avery', 'David', 'Ella'
    )[UNIFORM(0, 29, RANDOM())]::VARCHAR || ' ' ||
    ARRAY_CONSTRUCT(
        'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 
        'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez',
        'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin',
        'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark', 'Ramirez',
        'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott'
    )[UNIFORM(0, 35, RANDOM())]::VARCHAR AS customer_name,
    
    -- Email
    LOWER(REPLACE(customer_name, ' ', '.')) || UNIFORM(1, 999, RANDOM())::VARCHAR || '@email.com' AS email,
    
    -- UK phone format
    '+44 7' || UNIFORM(100, 999, RANDOM())::VARCHAR || ' ' || 
    UNIFORM(100000, 999999, RANDOM())::VARCHAR AS phone,
    
    -- Date of birth (ages 22-75)
    DATEADD('year', -UNIFORM(22, 75, RANDOM()), CURRENT_DATE()) AS date_of_birth,
    
    -- Customer segment (weighted distribution)
    CASE 
        WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 'MASS_MARKET'
        WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'MASS_AFFLUENT'
        WHEN UNIFORM(1, 100, RANDOM()) <= 95 THEN 'AFFLUENT'
        ELSE 'HIGH_NET_WORTH'
    END AS customer_segment,
    
    -- UK regions
    ARRAY_CONSTRUCT(
        'London', 'South East', 'South West', 'East of England', 'West Midlands',
        'East Midlands', 'Yorkshire', 'North West', 'North East', 'Scotland', 'Wales'
    )[UNIFORM(0, 10, RANDOM())]::VARCHAR AS region,
    
    -- Onboarding channel
    ARRAY_CONSTRUCT('BRANCH', 'ONLINE', 'MOBILE_APP', 'REFERRAL', 'PARTNERSHIP')
    [UNIFORM(0, 4, RANDOM())]::VARCHAR AS onboarding_channel,
    
    -- Onboarding date (1 month to 15 years ago)
    DATEADD('day', -UNIFORM(30, 5475, RANDOM()), CURRENT_DATE()) AS onboarding_date,
    
    -- KYC status
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 98 THEN 'VERIFIED' ELSE 'PENDING_REVIEW' END AS kyc_status

FROM TABLE(GENERATOR(ROWCOUNT => 1000));

SELECT '✅ Step 4a Complete: 1,000 customers created' AS status;


-- ----------------------------------------------------------------------
-- POPULATE ACCOUNTS (~2,500 accounts for 1,000 customers)
-- ----------------------------------------------------------------------
INSERT INTO ACCOUNTS (
    account_id, customer_id, account_type, product_name, account_status,
    opened_date, closed_date, current_balance, available_balance, 
    overdraft_limit, interest_rate, branch_code
)
WITH customer_base AS (
    SELECT customer_id, onboarding_date, customer_segment
    FROM CUSTOMERS
)
SELECT 
    'ACC-' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM())::VARCHAR, 8, '0') AS account_id,
    c.customer_id,
    
    -- Account type based on row number
    CASE MOD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 5)
        WHEN 0 THEN 'CURRENT_ACCOUNT'
        WHEN 1 THEN 'SAVINGS_ACCOUNT'
        WHEN 2 THEN 'CREDIT_CARD'
        WHEN 3 THEN 'LOAN'
        ELSE 'ISA'
    END AS account_type,
    
    -- Product name
    CASE MOD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 5)
        WHEN 0 THEN 'Everyday Current'
        WHEN 1 THEN 'Easy Saver'
        WHEN 2 THEN 'Rewards Credit Card'
        WHEN 3 THEN 'Personal Loan'
        ELSE 'Cash ISA'
    END AS product_name,
    
    -- Status (5% closed)
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN 'CLOSED' ELSE 'ACTIVE' END AS account_status,
    
    -- Opened date (after onboarding)
    DATEADD('day', UNIFORM(0, 365, RANDOM()), c.onboarding_date) AS opened_date,
    
    -- Closed date (only if closed)
    NULL AS closed_date,
    
    -- Balances based on segment
    CASE c.customer_segment
        WHEN 'HIGH_NET_WORTH' THEN UNIFORM(50000, 500000, RANDOM())
        WHEN 'AFFLUENT' THEN UNIFORM(10000, 100000, RANDOM())
        WHEN 'MASS_AFFLUENT' THEN UNIFORM(2000, 30000, RANDOM())
        ELSE UNIFORM(100, 5000, RANDOM())
    END::NUMBER(15,2) AS current_balance,
    
    CASE c.customer_segment
        WHEN 'HIGH_NET_WORTH' THEN UNIFORM(45000, 480000, RANDOM())
        WHEN 'AFFLUENT' THEN UNIFORM(8000, 95000, RANDOM())
        WHEN 'MASS_AFFLUENT' THEN UNIFORM(1500, 28000, RANDOM())
        ELSE UNIFORM(50, 4500, RANDOM())
    END::NUMBER(15,2) AS available_balance,
    
    -- Overdraft limit (only for current accounts)
    CASE MOD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 5)
        WHEN 0 THEN UNIFORM(500, 5000, RANDOM())
        ELSE 0
    END::NUMBER(15,2) AS overdraft_limit,
    
    -- Interest rate
    CASE MOD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 5)
        WHEN 1 THEN UNIFORM(100, 450, RANDOM()) / 10000.0  -- Savings: 1-4.5%
        WHEN 2 THEN UNIFORM(1500, 2500, RANDOM()) / 10000.0 -- Credit: 15-25%
        WHEN 3 THEN UNIFORM(500, 1500, RANDOM()) / 10000.0  -- Loan: 5-15%
        ELSE NULL
    END AS interest_rate,
    
    -- Branch code
    'BR-' || LPAD(UNIFORM(1, 500, RANDOM())::VARCHAR, 4, '0') AS branch_code

FROM customer_base c,
     LATERAL (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3) multiplier
WHERE UNIFORM(1, 10, RANDOM()) <= 8;  -- ~80% chance per row = avg 2.4 accounts per customer

SELECT '✅ Step 4b Complete: ~2,500 accounts created' AS status;


-- ----------------------------------------------------------------------
-- POPULATE TRANSACTIONS (~25,000 transactions over last 6 months)
-- ----------------------------------------------------------------------
INSERT INTO TRANSACTIONS (
    txn_id, account_id, txn_date, txn_timestamp, txn_type, txn_category,
    amount, balance_after, channel, merchant_category, description
)
WITH active_accounts AS (
    SELECT 
        a.account_id, 
        a.account_type,
        a.current_balance,
        c.customer_segment
    FROM ACCOUNTS a
    JOIN CUSTOMERS c ON a.customer_id = c.customer_id
    WHERE a.account_status = 'ACTIVE'
      AND a.account_type IN ('CURRENT_ACCOUNT', 'CREDIT_CARD')
    LIMIT 500  -- Limit accounts for manageable transaction volume
),
txn_dates AS (
    SELECT DATEADD('day', -SEQ4(), CURRENT_DATE()) AS txn_date
    FROM TABLE(GENERATOR(ROWCOUNT => 180))  -- Last 6 months
)
SELECT 
    'TXN-' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM())::VARCHAR, 10, '0') AS txn_id,
    aa.account_id,
    td.txn_date,
    DATEADD('second', UNIFORM(0, 86399, RANDOM()), td.txn_date::TIMESTAMP_NTZ) AS txn_timestamp,
    
    -- Transaction type
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'DIRECT_DEBIT'
        WHEN 2 THEN 'STANDING_ORDER'
        WHEN 3 THEN 'CARD_PAYMENT'
        WHEN 4 THEN 'CARD_PAYMENT'
        WHEN 5 THEN 'CARD_PAYMENT'
        WHEN 6 THEN 'TRANSFER_OUT'
        WHEN 7 THEN 'TRANSFER_IN'
        WHEN 8 THEN 'ATM_WITHDRAWAL'
        WHEN 9 THEN 'SALARY_CREDIT'
        ELSE 'INTEREST'
    END AS txn_type,
    
    -- Category
    ARRAY_CONSTRUCT(
        'GROCERIES', 'UTILITIES', 'ENTERTAINMENT', 'TRANSPORT', 'DINING',
        'SHOPPING', 'HEALTHCARE', 'INSURANCE', 'SUBSCRIPTIONS', 'OTHER'
    )[UNIFORM(0, 9, RANDOM())]::VARCHAR AS txn_category,
    
    -- Amount (varies by type)
    UNIFORM(-500, 2000, RANDOM())::NUMBER(15,2) AS amount,
    
    -- Balance after (simplified)
    aa.current_balance + UNIFORM(-500, 500, RANDOM()) AS balance_after,
    
    -- Channel
    ARRAY_CONSTRUCT('MOBILE_APP', 'ONLINE', 'BRANCH', 'ATM', 'MERCHANT', 'AUTO')
    [UNIFORM(0, 5, RANDOM())]::VARCHAR AS channel,
    
    -- Merchant category
    ARRAY_CONSTRUCT(
        'SUPERMARKET', 'RESTAURANT', 'FUEL', 'RETAIL', 'ONLINE_SHOPPING',
        'TRAVEL', 'ENTERTAINMENT', 'HEALTH', 'SERVICES'
    )[UNIFORM(0, 8, RANDOM())]::VARCHAR AS merchant_category,
    
    -- Description
    'Transaction on ' || td.txn_date::VARCHAR AS description

FROM active_accounts aa
CROSS JOIN txn_dates td
WHERE UNIFORM(1, 100, RANDOM()) <= 25;  -- ~25% sampling for manageable volume

SELECT '✅ Step 4c Complete: ~25,000 transactions created' AS status;


-- ----------------------------------------------------------------------
-- POPULATE DIGITAL_ENGAGEMENT (latest snapshot for all customers)
-- ----------------------------------------------------------------------
INSERT INTO DIGITAL_ENGAGEMENT (
    engagement_id, customer_id, measurement_date, login_count_30d,
    mobile_app_active, online_banking_active, last_login_date, last_login_channel,
    session_count_30d, avg_session_minutes, features_used_count, push_notifications_enabled
)
SELECT 
    'ENG-' || LPAD(engagement_seq.NEXTVAL::VARCHAR, 6, '0') AS engagement_id,
    customer_id,
    CURRENT_DATE() AS measurement_date,
    
    -- Login count (varies - some customers very active, some dormant)
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 0  -- 10% dormant
        WHEN 2 THEN UNIFORM(1, 3, RANDOM())  -- Low engagement
        WHEN 3 THEN UNIFORM(1, 3, RANDOM())
        WHEN 4 THEN UNIFORM(4, 10, RANDOM())  -- Medium engagement
        WHEN 5 THEN UNIFORM(4, 10, RANDOM())
        WHEN 6 THEN UNIFORM(4, 10, RANDOM())
        ELSE UNIFORM(15, 60, RANDOM())  -- High engagement
    END AS login_count_30d,
    
    -- Mobile app active
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 70 THEN TRUE ELSE FALSE END AS mobile_app_active,
    
    -- Online banking active
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN TRUE ELSE FALSE END AS online_banking_active,
    
    -- Last login date
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN DATEADD('day', -UNIFORM(60, 180, RANDOM()), CURRENT_DATE())  -- Dormant
        WHEN 2 THEN DATEADD('day', -UNIFORM(30, 60, RANDOM()), CURRENT_DATE())
        ELSE DATEADD('day', -UNIFORM(0, 7, RANDOM()), CURRENT_DATE())  -- Recent
    END AS last_login_date,
    
    -- Last login channel
    ARRAY_CONSTRUCT('MOBILE_APP', 'ONLINE_BANKING', 'MOBILE_APP', 'MOBILE_APP')
    [UNIFORM(0, 3, RANDOM())]::VARCHAR AS last_login_channel,
    
    -- Session count
    UNIFORM(0, 50, RANDOM()) AS session_count_30d,
    
    -- Avg session minutes
    UNIFORM(1, 15, RANDOM()) + UNIFORM(0, 9, RANDOM()) / 10.0 AS avg_session_minutes,
    
    -- Features used
    UNIFORM(0, 12, RANDOM()) AS features_used_count,
    
    -- Push notifications
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 65 THEN TRUE ELSE FALSE END AS push_notifications_enabled

FROM CUSTOMERS;

SELECT '✅ Step 4d Complete: Digital engagement data created' AS status;


-- ----------------------------------------------------------------------
-- POPULATE COMPLAINTS (~200 complaints, 20% of customers have complained)
-- ----------------------------------------------------------------------
INSERT INTO COMPLAINTS (
    complaint_id, customer_id, complaint_date, category, subcategory,
    channel, severity, status, resolution_date, resolution_type,
    escalated, compensation_amount, root_cause, description
)
WITH complaining_customers AS (
    SELECT customer_id, onboarding_date
    FROM CUSTOMERS
    WHERE UNIFORM(1, 100, RANDOM()) <= 20  -- 20% have complaints
)
SELECT 
    'COMP-' || LPAD(complaint_seq.NEXTVAL::VARCHAR, 6, '0') AS complaint_id,
    cc.customer_id,
    
    -- Complaint date (within last 2 years)
    DATEADD('day', -UNIFORM(0, 730, RANDOM()), CURRENT_DATE()) AS complaint_date,
    
    -- Category
    ARRAY_CONSTRUCT(
        'SERVICE_QUALITY', 'FEES_AND_CHARGES', 'PRODUCT_ISSUE', 
        'DIGITAL_BANKING', 'FRAUD_DISPUTE', 'COMMUNICATION', 'WAITING_TIME'
    )[UNIFORM(0, 6, RANDOM())]::VARCHAR AS category,
    
    -- Subcategory
    ARRAY_CONSTRUCT(
        'Response Time', 'Staff Behaviour', 'Incorrect Information',
        'System Error', 'Unauthorized Transaction', 'Missing Statement',
        'App Crash', 'Password Issue', 'Payment Failure'
    )[UNIFORM(0, 8, RANDOM())]::VARCHAR AS subcategory,
    
    -- Channel
    ARRAY_CONSTRUCT('BRANCH', 'PHONE', 'EMAIL', 'MOBILE_APP', 'SOCIAL_MEDIA', 'LETTER')
    [UNIFORM(0, 5, RANDOM())]::VARCHAR AS channel,
    
    -- Severity
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'CRITICAL'
        WHEN 2 THEN 'HIGH'
        WHEN 3 THEN 'HIGH'
        ELSE 'MEDIUM'
    END AS severity,
    
    -- Status (80% resolved, 20% open)
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN 'RESOLVED' ELSE 'OPEN' END AS status,
    
    -- Resolution date
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 80 
         THEN DATEADD('day', UNIFORM(1, 30, RANDOM()), complaint_date)
         ELSE NULL 
    END AS resolution_date,
    
    -- Resolution type
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 80 THEN
        ARRAY_CONSTRUCT('APOLOGY', 'REFUND', 'PROCESS_CHANGE', 'COMPENSATION', 'EXPLANATION')
        [UNIFORM(0, 4, RANDOM())]::VARCHAR
    ELSE NULL END AS resolution_type,
    
    -- Escalated
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 15 THEN TRUE ELSE FALSE END AS escalated,
    
    -- Compensation
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 10 
         THEN UNIFORM(25, 500, RANDOM())::NUMBER(10,2)
         ELSE NULL 
    END AS compensation_amount,
    
    -- Root cause
    ARRAY_CONSTRUCT(
        'Human Error', 'System Issue', 'Process Gap', 'Third Party', 'Customer Misunderstanding'
    )[UNIFORM(0, 4, RANDOM())]::VARCHAR AS root_cause,
    
    'Customer complaint regarding service issue' AS description

FROM complaining_customers cc;

SELECT '✅ Step 4e Complete: ~200 complaints created' AS status;


-- ----------------------------------------------------------------------
-- OPTIMIZE TABLES WITH CLUSTERING KEYS
-- ----------------------------------------------------------------------
ALTER TABLE TRANSACTIONS CLUSTER BY (account_id, txn_date);
ALTER TABLE DIGITAL_ENGAGEMENT CLUSTER BY (customer_id, measurement_date);

SELECT '✅ Step 4 Complete: All sample data created and optimized' AS status;


-- ============================================================================
-- STEP 5: CREATE STREAMLIT APP (Inline Code - No File Upload Needed!)
-- ============================================================================

USE SCHEMA RETAIL_BANKING_DB.GOVERNANCE;

CREATE OR REPLACE STREAMLIT dbt_code_generator
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = 'DATA_PRODUCTS_WH'
    TITLE = 'dbt Code Generator'
    COMMENT = 'Generates dbt models from data contracts using Cortex LLM'
AS $code$
"""
============================================================================
DBT CODE GENERATOR - Streamlit in Snowflake (SiS) App
============================================================================
This app takes a Data Contract YAML as input and generates:
- dbt model SQL (transformation logic)
- schema.yml (documentation and tests)
- masking_policies.sql (Snowflake masking policies)

The contract's English definitions (derivation, behavior) are interpreted
by Cortex LLM to produce Snowflake-native SQL.
============================================================================
"""

import streamlit as st
import yaml
import json
from datetime import datetime
from typing import Dict, List, Optional
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark import Session

# ============================================================================
# PAGE CONFIGURATION
# ============================================================================
st.set_page_config(
    page_title="DBT Code Generator",
    page_icon="🛠️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.2rem;
        font-weight: bold;
        color: #1e3a8a;
        text-align: center;
        margin-bottom: 1.5rem;
        padding: 1rem;
        background: linear-gradient(90deg, #dbeafe 0%, #ede9fe 100%);
        border-radius: 0.5rem;
    }
    .section-header {
        font-size: 1.3rem;
        font-weight: bold;
        color: #374151;
        margin-top: 1.5rem;
        margin-bottom: 0.75rem;
        border-bottom: 2px solid #e5e7eb;
        padding-bottom: 0.5rem;
    }
    .contract-card {
        background-color: #f0f9ff;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #0ea5e9;
        margin: 0.5rem 0;
    }
    .success-box {
        background-color: #ecfdf5;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #10b981;
        margin: 0.5rem 0;
    }
    .output-card {
        background-color: #fefce8;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #eab308;
        margin: 0.5rem 0;
    }
</style>
""", unsafe_allow_html=True)


# ============================================================================
# SESSION INITIALIZATION
# ============================================================================
def initialize_session():
    """Initialize Snowflake session"""
    if 'session' not in st.session_state:
        try:
            st.session_state.session = get_active_session()
            session_info = st.session_state.session.sql("""
                SELECT 
                    CURRENT_USER() as user,
                    CURRENT_DATABASE() as database,
                    CURRENT_SCHEMA() as schema,
                    CURRENT_WAREHOUSE() as warehouse
            """).collect()[0]
            st.session_state.session_info = {
                'user': session_info['USER'],
                'database': session_info['DATABASE'],
                'schema': session_info['SCHEMA'],
                'warehouse': session_info['WAREHOUSE']
            }
        except Exception as e:
            st.error(f"Failed to connect to Snowflake: {str(e)}")
            st.session_state.session = None


def execute_sql(sql: str, session: Session) -> List[Dict]:
    """Execute SQL and return results as list of dicts"""
    try:
        result = session.sql(sql).collect()
        return [row.as_dict() for row in result]
    except Exception as e:
        st.warning(f"SQL Error: {str(e)}")
        return []


# ============================================================================
# CONTRACT PARSING
# ============================================================================
def parse_contract(contract_yaml: str) -> Optional[Dict]:
    """Parse YAML contract and extract key information"""
    try:
        contract = yaml.safe_load(contract_yaml)
        return contract
    except yaml.YAMLError as e:
        st.error(f"Invalid YAML: {str(e)}")
        return None


def extract_contract_info(contract: Dict) -> Dict:
    """Extract key information from contract for display and generation"""
    metadata = contract.get('metadata', {})
    spec = contract.get('spec', {})
    source = spec.get('source', {})
    destination = spec.get('destination', {})
    schema = spec.get('schema', {})
    
    # Extract columns from schema properties with derivation info
    columns = []
    properties = schema.get('properties', {})
    for col_name, col_spec in properties.items():
        columns.append({
            'name': col_name,
            'type': col_spec.get('type', 'string'),
            'description': col_spec.get('description', ''),
            'derivation': col_spec.get('derivation', col_spec.get('source', '')),
            'required': col_spec.get('constraints', {}).get('required', False),
            'pii': col_spec.get('pii', False),
            'tags': col_spec.get('tags', []),
            'masking_policy': col_spec.get('masking_policy')
        })
    
    # Extract upstream tables with their details
    upstream_tables = source.get('upstream_tables', [])
    if isinstance(upstream_tables, list) and len(upstream_tables) > 0:
        if isinstance(upstream_tables[0], dict):
            source_tables = upstream_tables
        else:
            source_tables = [{'name': t.split('.')[-1], 'location': t} for t in upstream_tables]
    else:
        source_tables = []
    
    return {
        'name': metadata.get('name', 'unknown'),
        'version': metadata.get('version', '1.0.0'),
        'title': spec.get('info', {}).get('title', ''),
        'description': spec.get('info', {}).get('description', ''),
        'owner': spec.get('info', {}).get('owner', {}),
        'source_tables': source_tables,
        'target_database': destination.get('database', ''),
        'target_schema': destination.get('schema', ''),
        'target_table': destination.get('table', ''),
        'materialization': destination.get('materialization', 'table'),
        'columns': columns,
        'grain': schema.get('grain', ''),
        'primary_key': schema.get('primary_key', ''),
        'data_quality': spec.get('data_quality', {}),
        'business_rules': spec.get('data_quality', {}).get('business_rules', []),
        'masking_policies': spec.get('masking_policies', {}),
        'access_control': spec.get('access_control', {}),
        'sla': spec.get('sla', {})
    }


# ============================================================================
# DBT MODEL GENERATION
# ============================================================================
def generate_dbt_model_prompt(contract_info: Dict) -> str:
    """Create prompt for Cortex to generate dbt model based on contract derivations"""
    
    columns_with_derivations = []
    for col in contract_info['columns']:
        derivation = col.get('derivation', '')
        if derivation:
            columns_with_derivations.append(
                f"  - {col['name']} ({col['type']}): {col['description']}\n"
                f"    DERIVATION: {derivation}"
            )
        else:
            columns_with_derivations.append(
                f"  - {col['name']} ({col['type']}): {col['description']}"
            )
    
    columns_desc = "\n".join(columns_with_derivations)
    
    source_info = []
    for table in contract_info['source_tables']:
        if isinstance(table, dict):
            name = table.get('name', '')
            location = table.get('location', '')
            key_cols = table.get('key_columns', [])
            filter_cond = table.get('filter', '')
            source_info.append(
                f"  - {name} ({location})\n"
                f"    Key columns: {', '.join(key_cols) if key_cols else 'N/A'}\n"
                f"    Filter: {filter_cond if filter_cond else 'None'}"
            )
        else:
            source_info.append(f"  - {table}")
    
    source_tables = "\n".join(source_info)
    
    prompt = f"""You are an expert dbt developer generating Snowflake SQL. 
Generate a production-ready dbt model based on this data contract.

IMPORTANT: Generate ONLY valid SQL code. No explanations, just the complete dbt model.

DATA CONTRACT:
- Name: {contract_info['name']}
- Title: {contract_info['title']}
- Grain: {contract_info['grain']}
- Primary Key: {contract_info['primary_key']}

SOURCE TABLES:
{source_tables}

OUTPUT COLUMNS (with derivation logic):
{columns_desc}

REQUIREMENTS:
1. Start with dbt config block: materialized='{contract_info['materialization']}', unique_key='{contract_info['primary_key']}'
2. Use Snowflake SQL syntax
3. Use CTEs for each source table and aggregation step
4. Use dbt source() function for source tables: source('raw', 'table_name')
5. Implement ALL derivation logic exactly as specified
6. Handle NULLs with COALESCE where appropriate
7. Include comments for complex calculations
8. Output all specified columns in the final SELECT

Generate the complete SQL now:"""

    return prompt


def generate_masking_policy_prompt(policy_name: str, policy_def: Dict, contract_info: Dict) -> str:
    """Create prompt for Cortex to generate Snowflake masking policy"""
    
    authorized_roles = policy_def.get('authorized_roles', 
                                      contract_info.get('access_control', {}).get('authorized_roles', []))
    
    prompt = f"""Generate a Snowflake masking policy SQL based on this specification.

POLICY NAME: {policy_name}
DATA TYPE: {policy_def.get('data_type', 'STRING')}
APPLIES TO: {policy_def.get('applies_to', '')}
DESCRIPTION: {policy_def.get('description', '')}

BEHAVIOR:
{policy_def.get('behavior', 'Show full value for authorized roles, mask for others')}

AUTHORIZED ROLES:
{', '.join(authorized_roles)}

Generate ONLY the CREATE MASKING POLICY statement using Snowflake native functions.
Use CURRENT_ROLE() for role checking.
Use LEFT(), CONCAT() for string manipulation - no regex.
Include a COMMENT ON MASKING POLICY statement.

SQL:"""
    
    return prompt


def generate_schema_yml(contract_info: Dict) -> str:
    """Generate dbt schema.yml with tests and documentation from contract"""
    
    model_name = contract_info['target_table'].lower()
    
    sources_yaml = {
        'version': 2,
        'sources': [{
            'name': 'raw',
            'database': contract_info['target_database'],
            'schema': 'RAW',
            'tables': []
        }]
    }
    
    for table in contract_info['source_tables']:
        if isinstance(table, dict):
            table_def = {
                'name': table.get('name', '').lower(),
                'description': table.get('description', '')
            }
        else:
            table_def = {'name': table.split('.')[-1].lower()}
        sources_yaml['sources'][0]['tables'].append(table_def)
    
    columns_yaml = []
    for col in contract_info['columns']:
        col_def = {
            'name': col['name'],
            'description': col['description']
        }
        
        tests = []
        if col['name'] == contract_info['primary_key']:
            tests.extend(['unique', 'not_null'])
        elif col['required']:
            tests.append('not_null')
        
        if tests:
            col_def['tests'] = tests
        
        if col['tags']:
            col_def['tags'] = col['tags']
        
        columns_yaml.append(col_def)
    
    models_yaml = {
        'version': 2,
        'models': [{
            'name': model_name,
            'description': contract_info['description'],
            'config': {
                'materialized': contract_info['materialization'],
                'tags': ['data_product', 'generated_from_contract']
            },
            'meta': {
                'owner': contract_info['owner'].get('email', ''),
                'sla': contract_info['sla'].get('data_freshness', ''),
                'contract_version': contract_info['version']
            },
            'columns': columns_yaml
        }]
    }
    
    combined = "# ============================================================================\n"
    combined += "# SOURCES\n"
    combined += "# ============================================================================\n"
    combined += yaml.dump(sources_yaml, default_flow_style=False, sort_keys=False)
    combined += "\n\n"
    combined += "# ============================================================================\n"
    combined += "# MODELS\n"
    combined += "# ============================================================================\n"
    combined += yaml.dump(models_yaml, default_flow_style=False, sort_keys=False)
    
    return combined


def generate_masking_policies_sql(contract_info: Dict, session: Session = None, use_cortex: bool = False, model: str = "claude-3-5-sonnet") -> str:
    """Generate Snowflake masking policies SQL from contract"""
    
    masking_policies = contract_info.get('masking_policies', {})
    if not masking_policies:
        return "-- No masking policies defined in contract"
    
    sql_parts = [
        "-- ============================================================================",
        "-- MASKING POLICIES: Generated from Data Contract",
        "-- ============================================================================",
        f"-- Contract: {contract_info['name']} v{contract_info['version']}",
        f"-- Generated: {datetime.now().isoformat()}",
        "-- ============================================================================",
        "",
        f"USE ROLE ACCOUNTADMIN;",
        f"USE DATABASE {contract_info['target_database']};",
        f"USE SCHEMA {contract_info['target_schema']};",
        ""
    ]
    
    for policy_name, policy_def in masking_policies.items():
        authorized_roles = policy_def.get('authorized_roles', 
                                          contract_info.get('access_control', {}).get('authorized_roles', []))
        
        roles_sql = ", ".join([f"'{role.upper()}'" for role in authorized_roles])
        
        applies_to = policy_def.get('applies_to', '')
        description = policy_def.get('description', '')
        behavior = policy_def.get('behavior', '')
        data_type = policy_def.get('data_type', 'STRING')
        
        sql_parts.extend([
            f"-- ============================================================================",
            f"-- MASKING POLICY: {policy_name}",
            f"-- ============================================================================",
            f"-- Applies to: {applies_to}",
            f"-- Description: {description}",
            f"-- ============================================================================",
            "",
            f"CREATE OR REPLACE MASKING POLICY {policy_name.lower()}",
            f"AS (val {data_type})",
            f"RETURNS {data_type} ->",
            f"    CASE",
            f"        -- Authorized roles can see full value",
            f"        WHEN CURRENT_ROLE() IN ({roles_sql}) THEN val",
            f"        -- All other roles see masked value",
            f"        ELSE CONCAT(LEFT(val, 1), '****')",
            f"    END;",
            "",
            f"COMMENT ON MASKING POLICY {policy_name.lower()} IS",
            f"'{description}. Contract: {contract_info['name']} v{contract_info['version']}';",
            ""
        ])
        
        if applies_to:
            sql_parts.extend([
                f"-- Apply masking policy to column",
                f"ALTER TABLE IF EXISTS {contract_info['target_database']}.{contract_info['target_schema']}.{contract_info['target_table']}",
                f"    MODIFY COLUMN {applies_to}",
                f"    SET MASKING POLICY {policy_name.lower()};",
                ""
            ])
    
    return "\n".join(sql_parts)


def call_cortex(session: Session, prompt: str, model: str = "claude-3-5-sonnet") -> str:
    """Call Cortex LLM to generate code"""
    try:
        escaped_prompt = prompt.replace("'", "''")
        sql = f"SELECT SNOWFLAKE.CORTEX.COMPLETE('{model}', '{escaped_prompt}') as response"
        result = session.sql(sql).collect()
        
        if result and result[0]['RESPONSE']:
            return result[0]['RESPONSE']
        return "-- Error: No response from Cortex"
    except Exception as e:
        return f"-- Error generating code: {str(e)}"


# ============================================================================
# MAIN APPLICATION
# ============================================================================

initialize_session()

st.markdown('<div class="main-header">🛠️ DBT Code Generator from Data Contract</div>', unsafe_allow_html=True)

if st.session_state.session is None:
    st.error("❌ Unable to connect to Snowflake. Please check your environment.")
    st.stop()

with st.sidebar:
    st.header("❄️ Connection")
    if hasattr(st.session_state, 'session_info'):
        info = st.session_state.session_info
        st.write(f"**User:** {info['user']}")
        st.write(f"**Database:** {info['database']}")
        st.write(f"**Warehouse:** {info['warehouse']}")
    
    st.divider()
    
    st.header("🧠 Generation Settings")
    use_cortex = st.checkbox("Use Cortex LLM", value=True, 
                             help="Use Cortex AI to generate transformation code from contract derivations.")
    
    if use_cortex:
        cortex_model = st.selectbox(
            "Cortex Model",
            ["claude-3-5-sonnet", "llama3.1-70b", "mixtral-8x7b"],
            help="Select the LLM model for code generation"
        )
    else:
        cortex_model = None
        st.warning("⚠️ Without Cortex, only basic templates will be generated.")
    
    st.divider()
    
    st.header("📤 Outputs Generated")
    st.markdown("""
    The generator produces:
    - `model.sql` - dbt transformation
    - `schema.yml` - documentation & tests
    - `masking_policies.sql` - Snowflake policies
    """)
    
    st.divider()
    
    st.header("ℹ️ How It Works")
    st.markdown("""
    1. **Input**: Data Contract YAML
    2. **Parse**: Extract derivations & rules
    3. **Generate**: Cortex creates SQL from English definitions
    4. **Output**: Download files for dbt project
    """)

st.markdown('<div class="section-header">📋 Step 1: Provide Data Contract</div>', unsafe_allow_html=True)

input_method = st.radio(
    "How would you like to provide the contract?",
    ["📝 Paste YAML", "📁 Upload File", "☁️ Load from Stage"],
    horizontal=True
)

contract_yaml = None

if input_method == "📝 Paste YAML":
    contract_yaml = st.text_area(
        "Paste your Data Contract YAML here:",
        height=300,
        placeholder="apiVersion: v1\nkind: DataContract\nmetadata:\n  name: my-data-product\n..."
    )
    
elif input_method == "📁 Upload File":
    uploaded_file = st.file_uploader("Upload YAML file", type=['yaml', 'yml'])
    if uploaded_file:
        contract_yaml = uploaded_file.read().decode('utf-8')
        st.success(f"✅ Loaded: {uploaded_file.name}")

elif input_method == "☁️ Load from Stage":
    col1, col2 = st.columns(2)
    with col1:
        stage_path = st.text_input(
            "Stage Path",
            value="RETAIL_BANKING_DB.GOVERNANCE.DATA_CONTRACTS",
            help="e.g., RETAIL_BANKING_DB.GOVERNANCE.DATA_CONTRACTS"
        )
    with col2:
        file_name = st.text_input(
            "File Name",
            placeholder="contract.yaml"
        )
    
    if stage_path and file_name and st.button("Load from Stage"):
        try:
            session = st.session_state.session
            sql = f"""
                SELECT $1 as content 
                FROM @{stage_path}/{file_name}
                (FILE_FORMAT => (TYPE = 'CSV' FIELD_DELIMITER = NONE))
            """
            result = session.sql(sql).collect()
            if result:
                contract_yaml = '\n'.join([row['CONTENT'] for row in result])
                st.success(f"✅ Loaded from stage: {file_name}")
        except Exception as e:
            st.error(f"Error loading from stage: {str(e)}")

if contract_yaml:
    contract = parse_contract(contract_yaml)
    
    if contract:
        contract_info = extract_contract_info(contract)
        
        st.markdown('<div class="section-header">📊 Step 2: Review Contract Information</div>', unsafe_allow_html=True)
        
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown('<div class="contract-card">', unsafe_allow_html=True)
            st.markdown("**📌 Contract Details**")
            st.write(f"**Name:** {contract_info['name']}")
            st.write(f"**Version:** {contract_info['version']}")
            st.write(f"**Title:** {contract_info['title']}")
            st.write(f"**Owner:** {contract_info['owner'].get('name', 'N/A')}")
            st.markdown('</div>', unsafe_allow_html=True)
        
        with col2:
            st.markdown('<div class="contract-card">', unsafe_allow_html=True)
            st.markdown("**🎯 Target Configuration**")
            st.write(f"**Database:** {contract_info['target_database']}")
            st.write(f"**Schema:** {contract_info['target_schema']}")
            st.write(f"**Table:** {contract_info['target_table']}")
            st.write(f"**Materialization:** {contract_info['materialization']}")
            st.markdown('</div>', unsafe_allow_html=True)
        
        with st.expander("📥 Source Tables", expanded=True):
            for table in contract_info['source_tables']:
                if isinstance(table, dict):
                    st.write(f"• **{table.get('name')}** (`{table.get('location')}`)")
                    if table.get('filter'):
                        st.write(f"  Filter: _{table.get('filter')}_")
                else:
                    st.write(f"• `{table}`")
        
        with st.expander(f"📋 Output Columns ({len(contract_info['columns'])} columns)", expanded=False):
            for col in contract_info['columns']:
                pii_badge = "🔒 PII" if col['pii'] else ""
                derivation = col.get('derivation', '')
                st.write(f"• **{col['name']}** ({col['type']}) {pii_badge}")
                st.write(f"  _{col['description']}_")
                if derivation:
                    st.info(f"  📐 Derivation: {derivation[:200]}...")
        
        if contract_info.get('masking_policies'):
            with st.expander("🔐 Masking Policies", expanded=False):
                for name, policy in contract_info['masking_policies'].items():
                    st.write(f"• **{name}**")
                    st.write(f"  _{policy.get('description', '')}_")
        
        if contract_info.get('business_rules'):
            with st.expander("📏 Business Rules", expanded=False):
                for rule in contract_info['business_rules']:
                    if isinstance(rule, dict):
                        st.write(f"• **{rule.get('rule_id', 'N/A')}**: {rule.get('name', '')}")
                        st.write(f"  _{rule.get('description', '')}_")
        
        st.markdown('<div class="section-header">🚀 Step 3: Generate dbt Code</div>', unsafe_allow_html=True)
        
        if st.button("Generate All Outputs", type="primary", use_container_width=True):
            with st.spinner("Generating code from contract..."):
                
                if use_cortex:
                    prompt = generate_dbt_model_prompt(contract_info)
                    dbt_model_code = call_cortex(
                        st.session_state.session, 
                        prompt, 
                        cortex_model
                    )
                else:
                    dbt_model_code = f"-- Cortex disabled. Enable Cortex LLM for full generation.\n-- Contract: {contract_info['name']}"
                
                schema_yml = generate_schema_yml(contract_info)
                masking_sql = generate_masking_policies_sql(contract_info)
                
                st.session_state.generated_model = dbt_model_code
                st.session_state.generated_schema = schema_yml
                st.session_state.generated_masking = masking_sql
                st.session_state.model_name = contract_info['target_table'].lower()
        
        if hasattr(st.session_state, 'generated_model'):
            st.markdown('<div class="success-box">', unsafe_allow_html=True)
            st.markdown("✅ **All outputs generated successfully!**")
            st.markdown('</div>', unsafe_allow_html=True)
            
            tab1, tab2, tab3 = st.tabs(["📄 dbt Model SQL", "📋 schema.yml", "🔐 masking_policies.sql"])
            
            with tab1:
                st.code(st.session_state.generated_model, language='sql')
                st.download_button(
                    "📥 Download Model SQL",
                    st.session_state.generated_model,
                    file_name=f"{st.session_state.model_name}.sql",
                    mime="text/plain"
                )
            
            with tab2:
                st.code(st.session_state.generated_schema, language='yaml')
                st.download_button(
                    "📥 Download schema.yml",
                    st.session_state.generated_schema,
                    file_name="schema.yml",
                    mime="text/plain"
                )
            
            with tab3:
                st.code(st.session_state.generated_masking, language='sql')
                st.download_button(
                    "📥 Download masking_policies.sql",
                    st.session_state.generated_masking,
                    file_name="masking_policies.sql",
                    mime="text/plain"
                )
            
            st.markdown('<div class="section-header">📖 Next Steps</div>', unsafe_allow_html=True)
            
            st.markdown('<div class="output-card">', unsafe_allow_html=True)
            st.markdown(f"""
**Deploy to your dbt project:**

1. **Model SQL** → `models/data_products/{st.session_state.model_name}.sql`
2. **Schema** → `models/data_products/schema.yml`
3. **Masking** → Run `masking_policies.sql` in Snowflake

**Run dbt:**
```bash
dbt run --select {st.session_state.model_name}
dbt test --select {st.session_state.model_name}
```
            """)
            st.markdown('</div>', unsafe_allow_html=True)

else:
    st.info("👆 Please provide a data contract to get started.")
    
    with st.expander("📚 Example Contract Structure"):
        st.code("""
apiVersion: v1
kind: DataContract
metadata:
  name: retail-customer-churn-risk
  version: "1.0.0"
spec:
  info:
    title: "Retail Customer Churn Risk"
    description: "Churn risk scores for retail customers"
  source:
    upstream_tables:
      - name: "CUSTOMERS"
        location: "DB.RAW.CUSTOMERS"
        key_columns: ["customer_id", "name"]
        filter: "status = 'ACTIVE'"
  destination:
    database: "ANALYTICS_DB"
    schema: "DATA_PRODUCTS"
    table: "CUSTOMER_CHURN_RISK"
  schema:
    grain: "One row per customer"
    primary_key: "customer_id"
    properties:
      customer_id:
        type: "string"
        description: "Unique customer identifier"
        source: "CUSTOMERS.customer_id"
      churn_risk_score:
        type: "integer"
        description: "Risk score 0-100"
        derivation: |
          Calculate based on:
          - Balance decline: +20 points
          - Low engagement: +15 points
          Cap at 100
  masking_policies:
    NAME_MASK:
      description: "Mask name for unauthorized users"
      applies_to: "customer_name"
      data_type: "STRING"
      behavior: "Show first initial + asterisks for unauthorized roles"
      authorized_roles:
        - "analyst"
        - "manager"
        """, language='yaml')
$code$;

-- Grant access to all users
GRANT USAGE ON STREAMLIT dbt_code_generator TO ROLE PUBLIC;

SELECT '✅ Step 5 Complete: Streamlit app deployed (inline code)' AS status;


-- ============================================================================
-- STEP 6: VERIFY SETUP
-- ============================================================================

-- Data volume summary
SELECT '📊 DATA VOLUMES:' AS summary
UNION ALL SELECT '━━━━━━━━━━━━━━━━'
UNION ALL SELECT 'CUSTOMERS:          ' || COUNT(*)::VARCHAR FROM RETAIL_BANKING_DB.RAW.CUSTOMERS
UNION ALL SELECT 'ACCOUNTS:           ' || COUNT(*)::VARCHAR FROM RETAIL_BANKING_DB.RAW.ACCOUNTS
UNION ALL SELECT 'TRANSACTIONS:       ' || COUNT(*)::VARCHAR FROM RETAIL_BANKING_DB.RAW.TRANSACTIONS
UNION ALL SELECT 'DIGITAL_ENGAGEMENT: ' || COUNT(*)::VARCHAR FROM RETAIL_BANKING_DB.RAW.DIGITAL_ENGAGEMENT
UNION ALL SELECT 'COMPLAINTS:         ' || COUNT(*)::VARCHAR FROM RETAIL_BANKING_DB.RAW.COMPLAINTS;

-- Customer segment distribution
SELECT customer_segment, COUNT(*) AS count
FROM RETAIL_BANKING_DB.RAW.CUSTOMERS
GROUP BY customer_segment
ORDER BY count DESC;

-- Final summary
SELECT '═══════════════════════════════════════════════════════════' AS msg
UNION ALL SELECT '                    ✅ SETUP COMPLETE!                        '
UNION ALL SELECT '═══════════════════════════════════════════════════════════'
UNION ALL SELECT ''
UNION ALL SELECT 'WHAT WAS CREATED:'
UNION ALL SELECT '  • Database: RETAIL_BANKING_DB'
UNION ALL SELECT '  • Schemas: RAW, DATA_PRODUCTS, GOVERNANCE, MONITORING'
UNION ALL SELECT '  • Warehouse: DATA_PRODUCTS_WH (XS, auto-suspend 5min)'
UNION ALL SELECT '  • Sample Data: 5 tables with realistic FSI data'
UNION ALL SELECT '  • Stage: data_contracts (for uploading contract YAMLs)'
UNION ALL SELECT '  • Streamlit App: dbt_code_generator (inline code)'
UNION ALL SELECT ''
UNION ALL SELECT 'NEXT STEPS:'
UNION ALL SELECT '  1. Open Streamlit app: Snowsight → Projects → Streamlit'
UNION ALL SELECT '  2. Paste contract YAML or upload file'
UNION ALL SELECT '  3. Click "Generate All Outputs" to create dbt model'
UNION ALL SELECT '  4. Copy generated SQL and run in Snowsight'
UNION ALL SELECT '  5. Run: 03_deliver/02_generated_output/masking_policies.sql'
UNION ALL SELECT '  6. Run: 03_deliver/03_semantic_view_marketplace.sql'
UNION ALL SELECT '  7. Run: 04_operate/monitoring_observability.sql'
UNION ALL SELECT ''
UNION ALL SELECT '═══════════════════════════════════════════════════════════';
