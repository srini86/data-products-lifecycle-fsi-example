-- ============================================================================
-- SETUP.SQL - One-Click Setup for Data Products Code Sample
-- ============================================================================
-- This script sets up everything you need to run the demo:
-- 1. Database, schemas, warehouse
-- 2. Sample data (5 source tables, 10K customers)
-- 3. Stages for contracts and Streamlit app
-- 4. Streamlit dbt Generator app deployed
-- 5. Data contract uploaded to stage
--
-- PREREQUISITES:
-- - Snowflake account with ACCOUNTADMIN role
-- - SnowSQL or Snowsight access
--
-- USAGE:
-- Option 1 (SnowSQL): snowsql -f setup.sql
-- Option 2 (Snowsight): Open this file and run all
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- STEP 1: CREATE DATABASE AND SCHEMAS
-- ============================================================================

CREATE DATABASE IF NOT EXISTS RETAIL_BANKING_DB;
USE DATABASE RETAIL_BANKING_DB;

CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS DATA_PRODUCTS;
CREATE SCHEMA IF NOT EXISTS GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS MONITORING;

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE COMPUTE_WH;

PRINT '✅ Step 1 Complete: Database and schemas created';


-- ============================================================================
-- STEP 2: CREATE STAGES
-- ============================================================================

USE SCHEMA GOVERNANCE;

-- Stage for data contracts
CREATE STAGE IF NOT EXISTS data_contracts
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for data contract YAML files';

-- Stage for Streamlit apps
CREATE STAGE IF NOT EXISTS streamlit_apps
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Streamlit application files';

PRINT '✅ Step 2 Complete: Stages created';


-- ============================================================================
-- STEP 3: CREATE SAMPLE DATA
-- ============================================================================
-- Creates 5 source tables with realistic banking data

USE SCHEMA RAW;

-- 3a. CUSTOMERS table
CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id         VARCHAR(50) PRIMARY KEY,
    customer_name       VARCHAR(200) NOT NULL,
    email               VARCHAR(200),
    phone               VARCHAR(50),
    date_of_birth       DATE,
    customer_segment    VARCHAR(50),
    region              VARCHAR(100),
    onboarding_date     DATE,
    kyc_status          VARCHAR(20),
    preferred_channel   VARCHAR(50),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 3b. ACCOUNTS table
CREATE OR REPLACE TABLE ACCOUNTS (
    account_id          VARCHAR(50) PRIMARY KEY,
    customer_id         VARCHAR(50) NOT NULL,
    account_type        VARCHAR(50),
    account_status      VARCHAR(20),
    opening_date        DATE,
    current_balance     NUMBER(15,2),
    currency            VARCHAR(3) DEFAULT 'GBP',
    branch_code         VARCHAR(20),
    last_transaction_date DATE,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 3c. TRANSACTIONS table
CREATE OR REPLACE TABLE TRANSACTIONS (
    txn_id              VARCHAR(50) PRIMARY KEY,
    account_id          VARCHAR(50) NOT NULL,
    txn_date            DATE NOT NULL,
    txn_type            VARCHAR(50),
    amount              NUMBER(15,2),
    channel             VARCHAR(50),
    merchant_category   VARCHAR(100),
    description         VARCHAR(500),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 3d. DIGITAL_ENGAGEMENT table
CREATE OR REPLACE TABLE DIGITAL_ENGAGEMENT (
    engagement_id       VARCHAR(50) PRIMARY KEY,
    customer_id         VARCHAR(50) NOT NULL,
    measurement_date    DATE,
    login_count_30d     INTEGER,
    mobile_app_active   BOOLEAN,
    online_banking_active BOOLEAN,
    features_used_count INTEGER,
    last_login_date     DATE,
    app_version         VARCHAR(20),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 3e. COMPLAINTS table
CREATE OR REPLACE TABLE COMPLAINTS (
    complaint_id        VARCHAR(50) PRIMARY KEY,
    customer_id         VARCHAR(50) NOT NULL,
    complaint_date      DATE,
    category            VARCHAR(100),
    severity            VARCHAR(20),
    status              VARCHAR(20),
    resolution_date     DATE,
    channel             VARCHAR(50),
    description         VARCHAR(1000),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

PRINT '✅ Step 3a Complete: Tables created';

-- Populate CUSTOMERS (10,000 customers)
INSERT INTO CUSTOMERS (customer_id, customer_name, email, phone, date_of_birth, 
                       customer_segment, region, onboarding_date, kyc_status, preferred_channel)
SELECT 
    'CUST-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS customer_id,
    CONCAT(
        CASE MOD(SEQ4(), 20)
            WHEN 0 THEN 'James' WHEN 1 THEN 'Emma' WHEN 2 THEN 'Oliver' WHEN 3 THEN 'Sophia'
            WHEN 4 THEN 'William' WHEN 5 THEN 'Ava' WHEN 6 THEN 'Benjamin' WHEN 7 THEN 'Isabella'
            WHEN 8 THEN 'Lucas' WHEN 9 THEN 'Mia' WHEN 10 THEN 'Henry' WHEN 11 THEN 'Charlotte'
            WHEN 12 THEN 'Alexander' WHEN 13 THEN 'Amelia' WHEN 14 THEN 'Daniel' WHEN 15 THEN 'Harper'
            WHEN 16 THEN 'Matthew' WHEN 17 THEN 'Evelyn' WHEN 18 THEN 'Joseph' ELSE 'Abigail'
        END,
        ' ',
        CASE MOD(SEQ4(), 15)
            WHEN 0 THEN 'Smith' WHEN 1 THEN 'Johnson' WHEN 2 THEN 'Williams' WHEN 3 THEN 'Brown'
            WHEN 4 THEN 'Jones' WHEN 5 THEN 'Garcia' WHEN 6 THEN 'Miller' WHEN 7 THEN 'Davis'
            WHEN 8 THEN 'Wilson' WHEN 9 THEN 'Anderson' WHEN 10 THEN 'Taylor' WHEN 11 THEN 'Thomas'
            WHEN 12 THEN 'Moore' WHEN 13 THEN 'Martin' ELSE 'Jackson'
        END
    ) AS customer_name,
    LOWER(REPLACE(customer_name, ' ', '.')) || SEQ4()::VARCHAR || '@email.com' AS email,
    '+44 7' || LPAD(UNIFORM(100000000, 999999999, RANDOM())::VARCHAR, 9, '0') AS phone,
    DATEADD('day', -UNIFORM(7000, 25000, RANDOM()), CURRENT_DATE()) AS date_of_birth,
    CASE UNIFORM(1, 100, RANDOM())
        WHEN BETWEEN 1 AND 50 THEN 'MASS_MARKET'
        WHEN BETWEEN 51 AND 75 THEN 'MASS_AFFLUENT'
        WHEN BETWEEN 76 AND 90 THEN 'AFFLUENT'
        ELSE 'HIGH_NET_WORTH'
    END AS customer_segment,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'London' WHEN 1 THEN 'South East' WHEN 2 THEN 'North West'
        WHEN 3 THEN 'West Midlands' WHEN 4 THEN 'Yorkshire' WHEN 5 THEN 'Scotland'
        WHEN 6 THEN 'East Midlands' WHEN 7 THEN 'South West' WHEN 8 THEN 'Wales'
        ELSE 'Northern Ireland'
    END AS region,
    DATEADD('day', -UNIFORM(30, 3650, RANDOM()), CURRENT_DATE()) AS onboarding_date,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 95 THEN 'VERIFIED' ELSE 'PENDING' END AS kyc_status,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'MOBILE' WHEN 2 THEN 'ONLINE' WHEN 3 THEN 'BRANCH' ELSE 'PHONE'
    END AS preferred_channel
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

PRINT '✅ Step 3b Complete: 10,000 customers created';

-- Populate ACCOUNTS (~25,000 accounts)
INSERT INTO ACCOUNTS (account_id, customer_id, account_type, account_status, 
                      opening_date, current_balance, branch_code, last_transaction_date)
SELECT 
    'ACC-' || LPAD(ROW_NUMBER() OVER (ORDER BY c.customer_id, r.n)::VARCHAR, 8, '0') AS account_id,
    c.customer_id,
    CASE r.n 
        WHEN 1 THEN 'CURRENT_ACCOUNT'
        WHEN 2 THEN CASE UNIFORM(1,3,RANDOM()) WHEN 1 THEN 'SAVINGS' WHEN 2 THEN 'ISA' ELSE 'CREDIT_CARD' END
        ELSE CASE UNIFORM(1,3,RANDOM()) WHEN 1 THEN 'MORTGAGE' WHEN 2 THEN 'LOAN' ELSE 'INVESTMENT' END
    END AS account_type,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 90 THEN 'ACTIVE' ELSE 'DORMANT' END AS account_status,
    DATEADD('day', UNIFORM(0, 365, RANDOM()), c.onboarding_date) AS opening_date,
    CASE 
        WHEN c.customer_segment = 'HIGH_NET_WORTH' THEN UNIFORM(50000, 2000000, RANDOM())
        WHEN c.customer_segment = 'AFFLUENT' THEN UNIFORM(10000, 200000, RANDOM())
        WHEN c.customer_segment = 'MASS_AFFLUENT' THEN UNIFORM(5000, 50000, RANDOM())
        ELSE UNIFORM(100, 15000, RANDOM())
    END AS current_balance,
    'BR-' || LPAD(UNIFORM(1, 500, RANDOM())::VARCHAR, 3, '0') AS branch_code,
    DATEADD('day', -UNIFORM(0, 90, RANDOM()), CURRENT_DATE()) AS last_transaction_date
FROM CUSTOMERS c
CROSS JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3) r
WHERE UNIFORM(1, 10, RANDOM()) <= 8;

PRINT '✅ Step 3c Complete: ~25,000 accounts created';

-- Populate DIGITAL_ENGAGEMENT (one per customer)
INSERT INTO DIGITAL_ENGAGEMENT (engagement_id, customer_id, measurement_date, 
                                 login_count_30d, mobile_app_active, online_banking_active,
                                 features_used_count, last_login_date, app_version)
SELECT 
    'ENG-' || LPAD(ROW_NUMBER() OVER (ORDER BY customer_id)::VARCHAR, 6, '0') AS engagement_id,
    customer_id,
    CURRENT_DATE() AS measurement_date,
    CASE 
        WHEN customer_segment = 'HIGH_NET_WORTH' THEN UNIFORM(5, 30, RANDOM())
        WHEN customer_segment = 'AFFLUENT' THEN UNIFORM(3, 25, RANDOM())
        WHEN customer_segment = 'MASS_AFFLUENT' THEN UNIFORM(2, 20, RANDOM())
        ELSE UNIFORM(0, 15, RANDOM())
    END AS login_count_30d,
    UNIFORM(1, 100, RANDOM()) <= 70 AS mobile_app_active,
    UNIFORM(1, 100, RANDOM()) <= 80 AS online_banking_active,
    UNIFORM(0, 15, RANDOM()) AS features_used_count,
    DATEADD('day', -UNIFORM(0, 45, RANDOM()), CURRENT_DATE()) AS last_login_date,
    CASE UNIFORM(1, 4, RANDOM()) 
        WHEN 1 THEN '5.2.1' WHEN 2 THEN '5.1.0' WHEN 3 THEN '5.0.3' ELSE '4.9.8'
    END AS app_version
FROM CUSTOMERS
WHERE kyc_status = 'VERIFIED';

PRINT '✅ Step 3d Complete: Digital engagement data created';

-- Populate COMPLAINTS (~2,000 complaints)
INSERT INTO COMPLAINTS (complaint_id, customer_id, complaint_date, category,
                        severity, status, resolution_date, channel, description)
SELECT 
    'CMP-' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM())::VARCHAR, 6, '0') AS complaint_id,
    customer_id,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS complaint_date,
    CASE UNIFORM(1, 6, RANDOM())
        WHEN 1 THEN 'SERVICE_QUALITY' WHEN 2 THEN 'FEES_CHARGES' WHEN 3 THEN 'DIGITAL_ISSUES'
        WHEN 4 THEN 'PRODUCT_ISSUES' WHEN 5 THEN 'STAFF_BEHAVIOR' ELSE 'OTHER'
    END AS category,
    CASE UNIFORM(1, 10, RANDOM())
        WHEN BETWEEN 1 AND 5 THEN 'LOW'
        WHEN BETWEEN 6 AND 8 THEN 'MEDIUM'
        ELSE 'HIGH'
    END AS severity,
    CASE UNIFORM(1, 10, RANDOM())
        WHEN BETWEEN 1 AND 7 THEN 'RESOLVED'
        WHEN BETWEEN 8 AND 9 THEN 'OPEN'
        ELSE 'ESCALATED'
    END AS status,
    CASE WHEN status = 'RESOLVED' 
        THEN DATEADD('day', UNIFORM(1, 30, RANDOM()), complaint_date) 
        ELSE NULL 
    END AS resolution_date,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'PHONE' WHEN 2 THEN 'EMAIL' WHEN 3 THEN 'BRANCH' ELSE 'MOBILE_APP'
    END AS channel,
    'Customer complaint regarding ' || category AS description
FROM CUSTOMERS
WHERE UNIFORM(1, 100, RANDOM()) <= 20;

PRINT '✅ Step 3e Complete: ~2,000 complaints created';
PRINT '✅ Step 3 Complete: All sample data created';


-- ============================================================================
-- STEP 4: UPLOAD FILES TO STAGES
-- ============================================================================
/*
IMPORTANT: After running this script, upload these files using Snowsight or SnowSQL:

Using Snowsight (Web UI):
1. Go to Data → Databases → RETAIL_BANKING_DB → GOVERNANCE → Stages
2. Click "DATA_CONTRACTS" → "+ Files" → Upload:
   - 02_design/churn_risk_data_contract.yaml
3. Click "STREAMLIT_APPS" → "+ Files" → Upload:
   - 03_deliver/01_dbt_generator_app.py

Using SnowSQL:
PUT file://02_design/churn_risk_data_contract.yaml @RETAIL_BANKING_DB.GOVERNANCE.data_contracts AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://03_deliver/01_dbt_generator_app.py @RETAIL_BANKING_DB.GOVERNANCE.streamlit_apps AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
*/

PRINT '⚠️  Step 4: MANUAL ACTION REQUIRED';
PRINT '    Upload these files to stages (see instructions above):';
PRINT '    - 02_design/churn_risk_data_contract.yaml → @GOVERNANCE.data_contracts';
PRINT '    - 03_deliver/01_dbt_generator_app.py → @GOVERNANCE.streamlit_apps';


-- ============================================================================
-- STEP 5: CREATE STREAMLIT APP
-- ============================================================================
-- Run this AFTER uploading the Python file to stage

USE SCHEMA GOVERNANCE;

CREATE OR REPLACE STREAMLIT dbt_code_generator
    ROOT_LOCATION = '@RETAIL_BANKING_DB.GOVERNANCE.streamlit_apps'
    MAIN_FILE = '01_dbt_generator_app.py'
    TITLE = 'dbt Code Generator'
    QUERY_WAREHOUSE = 'COMPUTE_WH'
    COMMENT = 'Generates dbt models from data contracts using Cortex LLM';

-- Grant access
GRANT USAGE ON STREAMLIT dbt_code_generator TO ROLE PUBLIC;

PRINT '✅ Step 5 Complete: Streamlit app created';
PRINT '    Open app at: https://app.snowflake.com → Projects → Streamlit → dbt_code_generator';


-- ============================================================================
-- STEP 6: VERIFY SETUP
-- ============================================================================

PRINT '';
PRINT '============================================================';
PRINT '                    SETUP COMPLETE!                          ';
PRINT '============================================================';
PRINT '';
PRINT 'What was created:';
PRINT '  ✅ Database: RETAIL_BANKING_DB';
PRINT '  ✅ Schemas: RAW, DATA_PRODUCTS, GOVERNANCE, MONITORING';
PRINT '  ✅ Sample Data: 10K customers, 25K accounts, 2K complaints';
PRINT '  ✅ Stages: data_contracts, streamlit_apps';
PRINT '  ✅ Streamlit App: dbt_code_generator';
PRINT '';
PRINT 'NEXT STEPS:';
PRINT '  1. Upload files to stages (see Step 4 above)';
PRINT '  2. Open Streamlit app and select contract from stage';
PRINT '  3. Generate dbt model code';
PRINT '  4. Run generated SQL to create data product table';
PRINT '  5. Run: 03_deliver/02_generated_output/masking_policies.sql';
PRINT '  6. Run: 03_deliver/03_semantic_view_marketplace.sql';
PRINT '  7. Run: 04_operate/monitoring_observability.sql';
PRINT '';
PRINT '============================================================';

-- Show table counts
SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM RAW.CUSTOMERS
UNION ALL SELECT 'ACCOUNTS', COUNT(*) FROM RAW.ACCOUNTS
UNION ALL SELECT 'DIGITAL_ENGAGEMENT', COUNT(*) FROM RAW.DIGITAL_ENGAGEMENT
UNION ALL SELECT 'COMPLAINTS', COUNT(*) FROM RAW.COMPLAINTS;

