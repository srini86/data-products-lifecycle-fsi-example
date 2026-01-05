-- ============================================================================
-- SAMPLE DATA LOADER: Retail Customer Churn Risk
-- ============================================================================
-- This script creates and populates sample source tables for the Retail 
-- Customer Churn Risk data product demonstration.
--
-- Uses native Snowflake functions (GENERATOR, UNIFORM, etc.) to create
-- realistic FSI sample data - NO PYTHON REQUIRED.
--
-- Run this script in Snowflake to set up the demo environment.
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE DATABASE AND SCHEMAS
-- ============================================================================
USE ROLE ACCOUNTADMIN;  -- Or your appropriate role

-- Create database for the demo
CREATE DATABASE IF NOT EXISTS RETAIL_BANKING_DB;
USE DATABASE RETAIL_BANKING_DB;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS RAW;           -- Source/staging data
CREATE SCHEMA IF NOT EXISTS DATA_PRODUCTS; -- Transformed data products
CREATE SCHEMA IF NOT EXISTS GOVERNANCE;    -- Tags, policies, contracts

USE SCHEMA RAW;

-- ============================================================================
-- STEP 2: CREATE SOURCE TABLES
-- ============================================================================

-- ----------------------------------------------------------------------
-- CUSTOMERS TABLE
-- Core customer demographics and profile information
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
-- ACCOUNTS TABLE
-- Customer accounts and products
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
-- TRANSACTIONS TABLE
-- Account transaction history
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
-- DIGITAL_ENGAGEMENT TABLE
-- Mobile app and online banking activity
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
-- COMPLAINTS TABLE
-- Customer complaints and service issues
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


-- ============================================================================
-- STEP 3: POPULATE SAMPLE DATA
-- ============================================================================

-- ----------------------------------------------------------------------
-- HELPER: Create sequences for ID generation
-- ----------------------------------------------------------------------
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


-- ----------------------------------------------------------------------
-- POPULATE ACCOUNTS (~2,500 accounts for 1,000 customers)
-- Average 2.5 products per customer
-- ----------------------------------------------------------------------
INSERT INTO ACCOUNTS (
    account_id, customer_id, account_type, product_name, account_status,
    opened_date, closed_date, current_balance, available_balance, 
    overdraft_limit, interest_rate, branch_code
)
WITH customer_base AS (
    SELECT customer_id, onboarding_date, customer_segment
    FROM CUSTOMERS
),
account_gen AS (
    SELECT 
        c.customer_id,
        c.onboarding_date,
        c.customer_segment,
        ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn,
        UNIFORM(1, 4, RANDOM()) AS num_accounts  -- 1-4 accounts per customer
    FROM customer_base c
)
SELECT 
    'ACC-' || LPAD(account_seq.NEXTVAL::VARCHAR, 8, '0') AS account_id,
    ag.customer_id,
    
    -- Account type based on product
    CASE MOD(seq.seq, 5)
        WHEN 0 THEN 'CURRENT_ACCOUNT'
        WHEN 1 THEN 'SAVINGS_ACCOUNT'
        WHEN 2 THEN 'CREDIT_CARD'
        WHEN 3 THEN 'LOAN'
        ELSE 'ISA'
    END AS account_type,
    
    -- Product name
    CASE MOD(seq.seq, 5)
        WHEN 0 THEN ARRAY_CONSTRUCT('Everyday Current', 'Premium Current', 'Student Account', 'Graduate Account')[UNIFORM(0,3,RANDOM())]::VARCHAR
        WHEN 1 THEN ARRAY_CONSTRUCT('Easy Saver', 'Fixed Rate Saver', 'Regular Saver', 'Notice Account')[UNIFORM(0,3,RANDOM())]::VARCHAR
        WHEN 2 THEN ARRAY_CONSTRUCT('Rewards Credit Card', 'Balance Transfer Card', 'Premium Card')[UNIFORM(0,2,RANDOM())]::VARCHAR
        WHEN 3 THEN ARRAY_CONSTRUCT('Personal Loan', 'Car Finance', 'Home Improvement Loan')[UNIFORM(0,2,RANDOM())]::VARCHAR
        ELSE ARRAY_CONSTRUCT('Cash ISA', 'Stocks & Shares ISA', 'Lifetime ISA')[UNIFORM(0,2,RANDOM())]::VARCHAR
    END AS product_name,
    
    -- Status (5% closed)
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN 'CLOSED' ELSE 'ACTIVE' END AS account_status,
    
    -- Opened date (after onboarding)
    DATEADD('day', UNIFORM(0, 365, RANDOM()), ag.onboarding_date) AS opened_date,
    
    -- Closed date (only if closed)
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 5 
         THEN DATEADD('day', UNIFORM(180, 1000, RANDOM()), ag.onboarding_date) 
         ELSE NULL 
    END AS closed_date,
    
    -- Balances based on segment
    CASE ag.customer_segment
        WHEN 'HIGH_NET_WORTH' THEN UNIFORM(50000, 500000, RANDOM())
        WHEN 'AFFLUENT' THEN UNIFORM(10000, 100000, RANDOM())
        WHEN 'MASS_AFFLUENT' THEN UNIFORM(2000, 30000, RANDOM())
        ELSE UNIFORM(100, 5000, RANDOM())
    END::NUMBER(15,2) AS current_balance,
    
    CASE ag.customer_segment
        WHEN 'HIGH_NET_WORTH' THEN UNIFORM(45000, 480000, RANDOM())
        WHEN 'AFFLUENT' THEN UNIFORM(8000, 95000, RANDOM())
        WHEN 'MASS_AFFLUENT' THEN UNIFORM(1500, 28000, RANDOM())
        ELSE UNIFORM(50, 4500, RANDOM())
    END::NUMBER(15,2) AS available_balance,
    
    -- Overdraft limit
    CASE MOD(seq.seq, 5)
        WHEN 0 THEN UNIFORM(500, 5000, RANDOM())
        ELSE 0
    END::NUMBER(15,2) AS overdraft_limit,
    
    -- Interest rate
    CASE MOD(seq.seq, 5)
        WHEN 1 THEN UNIFORM(100, 450, RANDOM()) / 10000.0  -- Savings: 1-4.5%
        WHEN 2 THEN UNIFORM(1500, 2500, RANDOM()) / 10000.0 -- Credit: 15-25%
        WHEN 3 THEN UNIFORM(500, 1500, RANDOM()) / 10000.0  -- Loan: 5-15%
        ELSE NULL
    END AS interest_rate,
    
    -- Branch code
    'BR-' || LPAD(UNIFORM(1, 500, RANDOM())::VARCHAR, 4, '0') AS branch_code

FROM account_gen ag
CROSS JOIN TABLE(GENERATOR(ROWCOUNT => 4)) seq
WHERE seq.seq < ag.num_accounts;


-- ----------------------------------------------------------------------
-- POPULATE TRANSACTIONS (~50,000 transactions over last 6 months)
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
),
txn_dates AS (
    SELECT DATEADD('day', -seq.seq, CURRENT_DATE()) AS txn_date
    FROM TABLE(GENERATOR(ROWCOUNT => 180)) seq  -- Last 6 months
)
SELECT 
    'TXN-' || LPAD(txn_seq.NEXTVAL::VARCHAR, 10, '0') AS txn_id,
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
    
    -- Amount (varies by type and segment)
    CASE 
        WHEN txn_type IN ('SALARY_CREDIT', 'TRANSFER_IN') THEN UNIFORM(1000, 8000, RANDOM())
        WHEN txn_type = 'DIRECT_DEBIT' THEN -UNIFORM(20, 500, RANDOM())
        WHEN txn_type = 'CARD_PAYMENT' THEN -UNIFORM(5, 200, RANDOM())
        WHEN txn_type = 'ATM_WITHDRAWAL' THEN -UNIFORM(20, 200, RANDOM())
        WHEN txn_type = 'TRANSFER_OUT' THEN -UNIFORM(50, 1000, RANDOM())
        ELSE UNIFORM(-100, 100, RANDOM())
    END::NUMBER(15,2) AS amount,
    
    -- Balance after (simplified)
    aa.current_balance + UNIFORM(-500, 500, RANDOM()) AS balance_after,
    
    -- Channel
    ARRAY_CONSTRUCT('MOBILE_APP', 'ONLINE', 'BRANCH', 'ATM', 'MERCHANT', 'AUTO')
    [UNIFORM(0, 5, RANDOM())]::VARCHAR AS channel,
    
    -- Merchant category
    CASE WHEN txn_type = 'CARD_PAYMENT' THEN
        ARRAY_CONSTRUCT(
            'SUPERMARKET', 'RESTAURANT', 'FUEL', 'RETAIL', 'ONLINE_SHOPPING',
            'TRAVEL', 'ENTERTAINMENT', 'HEALTH', 'SERVICES'
        )[UNIFORM(0, 8, RANDOM())]::VARCHAR
    ELSE NULL END AS merchant_category,
    
    -- Description
    'Transaction on ' || td.txn_date::VARCHAR AS description

FROM active_accounts aa
CROSS JOIN txn_dates td
WHERE UNIFORM(1, 100, RANDOM()) <= 
      CASE aa.customer_segment 
          WHEN 'HIGH_NET_WORTH' THEN 40
          WHEN 'AFFLUENT' THEN 30
          WHEN 'MASS_AFFLUENT' THEN 20
          ELSE 15
      END;


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


-- ============================================================================
-- STEP 4: CREATE INDEXES AND STATISTICS
-- ============================================================================

-- Clustering keys for better query performance
ALTER TABLE TRANSACTIONS CLUSTER BY (account_id, txn_date);
ALTER TABLE DIGITAL_ENGAGEMENT CLUSTER BY (customer_id, measurement_date);

-- ============================================================================
-- STEP 5: VERIFY DATA LOAD
-- ============================================================================
SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM CUSTOMERS
UNION ALL
SELECT 'ACCOUNTS', COUNT(*) FROM ACCOUNTS
UNION ALL
SELECT 'TRANSACTIONS', COUNT(*) FROM TRANSACTIONS
UNION ALL
SELECT 'DIGITAL_ENGAGEMENT', COUNT(*) FROM DIGITAL_ENGAGEMENT
UNION ALL
SELECT 'COMPLAINTS', COUNT(*) FROM COMPLAINTS;

-- Sample data quality check
SELECT 
    'Customer Segments' AS metric,
    customer_segment AS value,
    COUNT(*) AS count
FROM CUSTOMERS
GROUP BY customer_segment
ORDER BY count DESC;

-- Verify relationships
SELECT 
    'Accounts per Customer' AS metric,
    ROUND(AVG(account_count), 1) AS average,
    MIN(account_count) AS min_value,
    MAX(account_count) AS max_value
FROM (
    SELECT customer_id, COUNT(*) AS account_count
    FROM ACCOUNTS
    GROUP BY customer_id
);

SELECT 
    'Transactions per Account (last 30d)' AS metric,
    ROUND(AVG(txn_count), 1) AS average
FROM (
    SELECT account_id, COUNT(*) AS txn_count
    FROM TRANSACTIONS
    WHERE txn_date >= DATEADD('day', -30, CURRENT_DATE())
    GROUP BY account_id
);

-- ============================================================================
-- SAMPLE DATA LOAD COMPLETE
-- ============================================================================
-- You now have:
--   - ~1,000 customers across 4 segments
--   - ~2,500 accounts (mix of current, savings, credit, loans, ISAs)
--   - ~50,000 transactions over 6 months
--   - ~1,000 digital engagement records
--   - ~200 complaints
--
-- Next step: Run the dbt model to create the Churn Risk data product
-- ============================================================================

