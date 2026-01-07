-- ============================================================================
-- OPERATE: Monitoring & Observability for Retail Customer Churn Risk
-- ============================================================================
-- This script uses SNOWFLAKE NATIVE DATA QUALITY features:
-- 1. Data Metric Functions (DMFs) - system & custom
-- 2. Data Quality Monitoring
-- 3. SLA monitoring with native timestamps
-- 4. Usage telemetry via ACCOUNT_USAGE
-- 5. Alerts via Snowflake Alerts
--
-- Docs: https://docs.snowflake.com/en/user-guide/data-quality-intro
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;

-- Create monitoring schema
CREATE SCHEMA IF NOT EXISTS MONITORING;
USE SCHEMA MONITORING;


-- ============================================================================
-- PART 1: SET SCHEDULE FIRST (REQUIRED BEFORE ADDING DMFs)
-- ============================================================================
-- IMPORTANT: Schedule must exist before associating DMFs to the table
-- ============================================================================

-- Set monitoring schedule - DMFs run automatically every 30 minutes
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    SET DATA_METRIC_SCHEDULE = 'USING CRON 0,30 * * * * UTC';
    -- Alternative: 'TRIGGER_ON_CHANGES' to run only when data changes


-- ============================================================================
-- PART 2: SNOWFLAKE NATIVE DATA METRIC FUNCTIONS (DMFs)
-- ============================================================================
-- System DMFs: NULL_COUNT, DUPLICATE_COUNT, UNIQUE_COUNT, FRESHNESS, ROW_COUNT
-- These run automatically when scheduled and store results in INFORMATION_SCHEMA
-- ============================================================================

-- 2a. Apply System DMF: NULL_COUNT on critical columns (Expect: 0 nulls)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (customer_id)
    EXPECTATION no_null_customer_id (VALUE = 0);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (churn_risk_score)
    EXPECTATION no_null_risk_score (VALUE = 0);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
    ON (risk_tier)
    EXPECTATION no_null_risk_tier (VALUE = 0);

-- 2b. Apply System DMF: DUPLICATE_COUNT on primary key (Expect: 0 duplicates)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT 
    ON (customer_id)
    EXPECTATION no_duplicate_customer_id (VALUE = 0);

-- 2c. Apply System DMF: UNIQUE_COUNT for cardinality (informational, no expectation)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (customer_id);

ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT 
    ON (risk_tier);

-- 2d. Apply System DMF: FRESHNESS on timestamp column (Expect: <= 24 hours = 86400 sec)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS 
    ON (score_calculated_at)
    EXPECTATION freshness_sla_24h (VALUE <= 86400);

-- 2e. Apply System DMF: ROW_COUNT for completeness (Expect: >= 500 rows)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT 
    ON ()
    EXPECTATION min_row_count_500 (VALUE >= 500);


-- ============================================================================
-- PART 3: CUSTOM DATA METRIC FUNCTIONS
-- ============================================================================
-- Create custom DMFs for business-specific quality rules
-- ============================================================================

-- 3a. Custom DMF: Risk Score Range Validation (0-100)
CREATE OR REPLACE DATA METRIC FUNCTION risk_score_out_of_range(
    ARG_T TABLE(ARG_C NUMBER)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) 
    FROM ARG_T 
    WHERE ARG_C < 0 OR ARG_C > 100
$$;

-- Apply custom DMF (Expect: 0 out-of-range scores)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION MONITORING.risk_score_out_of_range 
    ON (churn_risk_score)
    EXPECTATION all_scores_in_range (VALUE = 0);

-- 3b. Custom DMF: Risk Tier Misalignment
CREATE OR REPLACE DATA METRIC FUNCTION risk_tier_misalignment(
    ARG_T TABLE(score NUMBER, tier VARCHAR)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM ARG_T
    WHERE NOT (
        (score <= 25 AND tier = 'LOW') OR
        (score > 25 AND score <= 50 AND tier = 'MEDIUM') OR
        (score > 50 AND score <= 75 AND tier = 'HIGH') OR
        (score > 75 AND tier = 'CRITICAL')
    )
$$;

-- Apply custom DMF (Expect: 0 misaligned rows)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION MONITORING.risk_tier_misalignment 
    ON (churn_risk_score, risk_tier)
    EXPECTATION tier_matches_score (VALUE = 0);

-- 3c. Custom DMF: Invalid Risk Tier Values
CREATE OR REPLACE DATA METRIC FUNCTION invalid_risk_tier(
    ARG_T TABLE(ARG_C VARCHAR)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM ARG_T
    WHERE ARG_C NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')
$$;

-- Apply custom DMF (Expect: 0 invalid tier values)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION MONITORING.invalid_risk_tier 
    ON (risk_tier)
    EXPECTATION valid_tier_values (VALUE = 0);

-- 3d. Custom DMF: High Risk Percentage (business threshold)
CREATE OR REPLACE DATA METRIC FUNCTION high_risk_percentage(
    ARG_T TABLE(ARG_C VARCHAR)
)
RETURNS NUMBER
AS
$$
    SELECT ROUND(
        SUM(CASE WHEN ARG_C IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(*), 0), 
        2
    )
    FROM ARG_T
$$;

-- Apply custom DMF (Expect: <= 35% high risk customers)
ALTER TABLE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    ADD DATA METRIC FUNCTION MONITORING.high_risk_percentage 
    ON (risk_tier)
    EXPECTATION high_risk_under_threshold (VALUE <= 35);


-- ============================================================================
-- PART 4: VIEW DMF RESULTS FROM INFORMATION_SCHEMA
-- ============================================================================
-- Query built-in views for DMF results
-- ============================================================================

-- 4a. View all DMFs and their expectations
CREATE OR REPLACE VIEW dmf_configuration AS
SELECT 
    metric_database_name,
    metric_schema_name,
    metric_name,
    ref_entity_name AS table_name,
    ref_arguments AS columns,
    schedule,
    schedule_status
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
        REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
);

-- 4b. View all expectations defined for this table (native view)
CREATE OR REPLACE VIEW dmf_expectations AS
SELECT 
    expectation_name,
    expectation_expression,
    metric_name,
    ref_entity_name AS table_name,
    ref_arguments AS columns
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_EXPECTATIONS(
        REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
);

-- 4c. View expectation violations (native view)
-- This shows PASS/FAIL status based on the EXPECTATION clauses defined above
CREATE OR REPLACE VIEW expectation_violations AS
SELECT 
    measurement_time,
    expectation_name,
    expectation_expression,
    metric_name,
    table_name,
    value AS dmf_result,
    CASE WHEN violation_status = TRUE THEN '❌ VIOLATED' ELSE '✅ MET' END AS status
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY measurement_time DESC;

-- 4d. Test expectations immediately without waiting for schedule
-- SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(
--     REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'));

-- 4e. View latest DMF results (Data Quality Monitoring Results)
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ EXPECTATIONS / THRESHOLDS                                                   │
-- ├────────────────────────┬────────────────────────────────────────────────────┤
-- │ Metric                 │ Expectation                                        │
-- ├────────────────────────┼────────────────────────────────────────────────────┤
-- │ NULL_COUNT             │ = 0 (no nulls in critical columns)                 │
-- │ DUPLICATE_COUNT        │ = 0 (customer_id must be unique)                   │
-- │ UNIQUE_COUNT           │ > 0 (informational, cardinality check)             │
-- │ ROW_COUNT              │ >= 500 (minimum expected records)                  │
-- │ FRESHNESS              │ <= 86400 seconds (24 hours SLA)                    │
-- │ RISK_SCORE_OUT_OF_RANGE│ = 0 (all scores between 0-100)                     │
-- │ RISK_TIER_MISALIGNMENT │ = 0 (score matches tier)                           │
-- │ INVALID_RISK_TIER      │ = 0 (only LOW/MEDIUM/HIGH/CRITICAL)                │
-- │ HIGH_RISK_PERCENTAGE   │ <= 35% (business threshold, WARN if exceeded)      │
-- └────────────────────────┴────────────────────────────────────────────────────┘

CREATE OR REPLACE VIEW data_quality_results AS
SELECT 
    measurement_time,
    metric_database || '.' || metric_schema || '.' || metric_name AS metric_full_name,
    metric_name,
    table_database || '.' || table_schema || '.' || table_name AS table_full_name,
    argument_names AS column_names,
    value AS metric_value,
    -- Expected thresholds
    CASE 
        WHEN metric_name = 'NULL_COUNT' THEN '= 0'
        WHEN metric_name = 'DUPLICATE_COUNT' THEN '= 0'
        WHEN metric_name = 'UNIQUE_COUNT' THEN '> 0'
        WHEN metric_name = 'ROW_COUNT' THEN '>= 500'
        WHEN metric_name = 'FRESHNESS' THEN '<= 86400 sec'
        WHEN metric_name = 'RISK_SCORE_OUT_OF_RANGE' THEN '= 0'
        WHEN metric_name = 'RISK_TIER_MISALIGNMENT' THEN '= 0'
        WHEN metric_name = 'INVALID_RISK_TIER' THEN '= 0'
        WHEN metric_name = 'HIGH_RISK_PERCENTAGE' THEN '<= 35%'
        ELSE 'N/A'
    END AS expectation,
    -- Pass/Fail evaluation
    CASE 
        -- System DMFs - interpret results
        WHEN metric_name = 'NULL_COUNT' AND value > 0 THEN 'FAIL'
        WHEN metric_name = 'DUPLICATE_COUNT' AND value > 0 THEN 'FAIL'
        WHEN metric_name = 'FRESHNESS' AND value > 86400 THEN 'FAIL'  -- > 24 hours in seconds
        WHEN metric_name = 'ROW_COUNT' AND value < 500 THEN 'FAIL'
        -- Custom DMFs
        WHEN metric_name = 'RISK_SCORE_OUT_OF_RANGE' AND value > 0 THEN 'FAIL'
        WHEN metric_name = 'RISK_TIER_MISALIGNMENT' AND value > 0 THEN 'FAIL'
        WHEN metric_name = 'INVALID_RISK_TIER' AND value > 0 THEN 'FAIL'
        WHEN metric_name = 'HIGH_RISK_PERCENTAGE' AND value > 35 THEN 'WARN'
        ELSE 'PASS'
    END AS quality_status
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY measurement_time DESC;

-- 4c. Latest quality summary by metric
CREATE OR REPLACE VIEW data_quality_summary AS
SELECT 
    metric_name,
    argument_names AS column_names,
    value AS latest_value,
    measurement_time AS last_checked,
    CASE 
        WHEN metric_name = 'NULL_COUNT' THEN 'Nulls in column: ' || value::VARCHAR
        WHEN metric_name = 'DUPLICATE_COUNT' THEN 'Duplicate rows: ' || value::VARCHAR
        WHEN metric_name = 'UNIQUE_COUNT' THEN 'Unique values: ' || value::VARCHAR
        WHEN metric_name = 'ROW_COUNT' THEN 'Total rows: ' || value::VARCHAR
        WHEN metric_name = 'FRESHNESS' THEN 'Age: ' || ROUND(value/3600, 1)::VARCHAR || ' hours'
        WHEN metric_name = 'RISK_SCORE_OUT_OF_RANGE' THEN 'Out of range: ' || value::VARCHAR
        WHEN metric_name = 'RISK_TIER_MISALIGNMENT' THEN 'Misaligned: ' || value::VARCHAR
        WHEN metric_name = 'HIGH_RISK_PERCENTAGE' THEN 'High risk: ' || value::VARCHAR || '%'
        ELSE value::VARCHAR
    END AS interpretation
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
QUALIFY ROW_NUMBER() OVER (PARTITION BY metric_name, argument_names ORDER BY measurement_time DESC) = 1;


-- ============================================================================
-- PART 5: SLA MONITORING (Using Native Table Metadata)
-- ============================================================================

-- 5a. Freshness status using native metadata
CREATE OR REPLACE VIEW data_freshness_status AS
SELECT 
    'RETAIL_CUSTOMER_CHURN_RISK' AS data_product_name,
    
    -- From DMF results
    (SELECT value 
     FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS 
     WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK' 
       AND metric_name = 'FRESHNESS'
     ORDER BY measurement_time DESC LIMIT 1) AS freshness_seconds,
    
    -- Calculate hours
    ROUND(freshness_seconds / 3600, 1) AS hours_since_refresh,
    
    -- SLA threshold (24 hours = 86400 seconds)
    24 AS sla_hours,
    
    -- Status
    CASE 
        WHEN freshness_seconds <= 86400 THEN 'FRESH'
        WHEN freshness_seconds <= 90000 THEN 'WARNING'  -- 25 hours grace
        ELSE 'STALE'
    END AS freshness_status,
    
    CASE 
        WHEN freshness_seconds <= 86400 THEN TRUE
        ELSE FALSE
    END AS sla_met,
    
    CURRENT_TIMESTAMP() AS checked_at;

-- 5b. Row count from native DMF
CREATE OR REPLACE VIEW row_count_status AS
SELECT 
    'RETAIL_CUSTOMER_CHURN_RISK' AS data_product_name,
    value AS row_count,
    500 AS minimum_threshold,
    CASE WHEN value >= 500 THEN 'PASS' ELSE 'FAIL' END AS status,
    measurement_time AS last_checked
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS 
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK' 
  AND metric_name = 'ROW_COUNT'
ORDER BY measurement_time DESC 
LIMIT 1;


-- ============================================================================
-- PART 6: USAGE TELEMETRY (Native ACCOUNT_USAGE)
-- ============================================================================

-- 6a. Query history for the data product
CREATE OR REPLACE VIEW data_product_usage AS
SELECT 
    query_id,
    user_name,
    role_name,
    warehouse_name,
    start_time,
    end_time,
    total_elapsed_time / 1000 AS duration_seconds,
    rows_produced,
    bytes_scanned,
    query_type,
    execution_status
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%RETAIL_CUSTOMER_CHURN_RISK%'
  AND start_time >= DATEADD('day', -30, CURRENT_DATE())
  AND execution_status = 'SUCCESS'
ORDER BY start_time DESC;

-- 6b. Usage by consumer role
CREATE OR REPLACE VIEW usage_by_consumer AS
SELECT 
    role_name,
    user_name,
    COUNT(*) AS query_count,
    SUM(rows_produced) AS total_rows_accessed,
    ROUND(AVG(duration_seconds), 2) AS avg_query_duration_sec,
    ROUND(SUM(bytes_scanned) / 1024 / 1024, 2) AS total_mb_scanned,
    MIN(start_time) AS first_access,
    MAX(start_time) AS last_access
FROM MONITORING.data_product_usage
GROUP BY role_name, user_name
ORDER BY query_count DESC;

-- 6c. Daily usage trends
CREATE OR REPLACE VIEW daily_usage_trends AS
SELECT 
    DATE(start_time) AS usage_date,
    COUNT(*) AS query_count,
    COUNT(DISTINCT user_name) AS unique_users,
    COUNT(DISTINCT role_name) AS unique_roles,
    SUM(rows_produced) AS total_rows,
    ROUND(AVG(duration_seconds), 2) AS avg_duration_sec,
    ROUND(SUM(bytes_scanned) / 1024 / 1024 / 1024, 3) AS total_gb_scanned
FROM MONITORING.data_product_usage
GROUP BY DATE(start_time)
ORDER BY usage_date DESC;


-- ============================================================================
-- PART 7: HEALTH DASHBOARD
-- ============================================================================

-- 7a. Executive health summary
CREATE OR REPLACE VIEW data_product_health_summary AS
SELECT 
    'RETAIL_CUSTOMER_CHURN_RISK' AS data_product_name,
    
    -- Row count from DMF
    (SELECT value FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS 
     WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK' AND metric_name = 'ROW_COUNT'
     ORDER BY measurement_time DESC LIMIT 1) AS total_records,
    
    -- Freshness from DMF
    (SELECT freshness_status FROM MONITORING.data_freshness_status) AS freshness_status,
    (SELECT hours_since_refresh FROM MONITORING.data_freshness_status) AS hours_since_refresh,
    
    -- DQ summary from DMF results
    (SELECT COUNT(*) FROM MONITORING.data_quality_results 
     WHERE quality_status = 'PASS' 
       AND measurement_time > DATEADD('day', -1, CURRENT_TIMESTAMP())) AS checks_passed_24h,
    
    (SELECT COUNT(*) FROM MONITORING.data_quality_results 
     WHERE quality_status = 'FAIL' 
       AND measurement_time > DATEADD('day', -1, CURRENT_TIMESTAMP())) AS checks_failed_24h,
    
    -- Usage stats
    (SELECT COUNT(*) FROM MONITORING.data_product_usage 
     WHERE start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())) AS queries_last_7d,
    
    (SELECT COUNT(DISTINCT user_name) FROM MONITORING.data_product_usage 
     WHERE start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())) AS unique_users_7d,
    
    -- Overall health
    CASE 
        WHEN (SELECT COUNT(*) FROM MONITORING.data_quality_results 
              WHERE quality_status = 'FAIL' 
                AND measurement_time > DATEADD('hour', -1, CURRENT_TIMESTAMP())) > 0 
        THEN 'DEGRADED'
        WHEN (SELECT freshness_status FROM MONITORING.data_freshness_status) = 'STALE' 
        THEN 'DEGRADED'
        ELSE 'HEALTHY'
    END AS overall_health,
    
    CURRENT_TIMESTAMP() AS report_generated_at;

-- 7b. Risk distribution summary
CREATE OR REPLACE VIEW risk_distribution_summary AS
SELECT 
    risk_tier,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
    ROUND(AVG(churn_risk_score), 1) AS avg_risk_score,
    ROUND(SUM(total_relationship_balance), 0) AS total_balance_at_risk,
    SUM(CASE WHEN recommended_intervention != 'NO_ACTION' THEN 1 ELSE 0 END) AS requiring_action
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
GROUP BY risk_tier
ORDER BY 
    CASE risk_tier 
        WHEN 'CRITICAL' THEN 1 
        WHEN 'HIGH' THEN 2 
        WHEN 'MEDIUM' THEN 3 
        ELSE 4 
    END;


-- ============================================================================
-- PART 8: SNOWFLAKE NATIVE ALERTS
-- ============================================================================

-- 8a. Alert for data quality failures (DMF-based)
CREATE OR REPLACE ALERT dq_failure_alert
    WAREHOUSE = DATA_PRODUCTS_WH
    SCHEDULE = '60 MINUTE'
    IF (EXISTS (
        SELECT 1 
        FROM MONITORING.data_quality_results 
        WHERE quality_status = 'FAIL'
          AND measurement_time > DATEADD('hour', -1, CURRENT_TIMESTAMP())
    ))
    THEN
        BEGIN
            -- Log the alert
            INSERT INTO MONITORING.alert_log (alert_name, alert_time, details)
            SELECT 
                'DATA_QUALITY_FAILURE',
                CURRENT_TIMESTAMP(),
                OBJECT_CONSTRUCT(
                    'failed_metrics', ARRAY_AGG(metric_name),
                    'table', 'RETAIL_CUSTOMER_CHURN_RISK'
                )
            FROM MONITORING.data_quality_results 
            WHERE quality_status = 'FAIL'
              AND measurement_time > DATEADD('hour', -1, CURRENT_TIMESTAMP());
        END;

-- 8b. Alert for freshness breach
CREATE OR REPLACE ALERT freshness_breach_alert
    WAREHOUSE = DATA_PRODUCTS_WH
    SCHEDULE = '60 MINUTE'
    IF (EXISTS (
        SELECT 1 
        FROM MONITORING.data_freshness_status 
        WHERE sla_met = FALSE
    ))
    THEN
        INSERT INTO MONITORING.alert_log (alert_name, alert_time, details)
        SELECT 
            'FRESHNESS_SLA_BREACH',
            CURRENT_TIMESTAMP(),
            OBJECT_CONSTRUCT(
                'hours_since_refresh', hours_since_refresh,
                'sla_hours', sla_hours,
                'table', 'RETAIL_CUSTOMER_CHURN_RISK'
            )
        FROM MONITORING.data_freshness_status;

-- 8c. Create alert log table
CREATE OR REPLACE TABLE alert_log (
    alert_id        VARCHAR(50) DEFAULT UUID_STRING(),
    alert_name      VARCHAR(100),
    alert_time      TIMESTAMP_NTZ,
    details         VARIANT,
    acknowledged    BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMP_NTZ,
    PRIMARY KEY (alert_id)
);

-- Enable alerts
ALTER ALERT dq_failure_alert RESUME;
ALTER ALERT freshness_breach_alert RESUME;


-- ============================================================================
-- PART 9: SAMPLE MONITORING QUERIES
-- ============================================================================

-- View all applied DMFs
SELECT * FROM MONITORING.dmf_configuration;

-- View all expectations defined
SELECT * FROM MONITORING.dmf_expectations;

-- View expectation violations (PASS/FAIL based on native EXPECTATION clause)
SELECT * FROM MONITORING.expectation_violations;

-- Test expectations immediately (without waiting for schedule)
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(
    REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'));

-- View latest DQ results
SELECT * FROM MONITORING.data_quality_results;

-- View DQ summary
SELECT * FROM MONITORING.data_quality_summary;

-- View overall health
SELECT * FROM MONITORING.data_product_health_summary;

-- View freshness status
SELECT * FROM MONITORING.data_freshness_status;

-- View usage trends
SELECT * FROM MONITORING.daily_usage_trends LIMIT 30;

-- View top consumers
SELECT * FROM MONITORING.usage_by_consumer LIMIT 20;

-- View alerts
SELECT * FROM MONITORING.alert_log ORDER BY alert_time DESC LIMIT 50;

-- View risk distribution
SELECT * FROM MONITORING.risk_distribution_summary;


-- ============================================================================
-- MONITORING SETUP COMPLETE
-- ============================================================================
-- Summary (Using Snowflake Native Features):
-- 
-- 1. SYSTEM DMFs Applied with EXPECTATIONS:
--    - NULL_COUNT on customer_id       → EXPECTATION: VALUE = 0
--    - NULL_COUNT on churn_risk_score  → EXPECTATION: VALUE = 0
--    - NULL_COUNT on risk_tier         → EXPECTATION: VALUE = 0
--    - DUPLICATE_COUNT on customer_id  → EXPECTATION: VALUE = 0
--    - UNIQUE_COUNT on customer_id     → (informational, no expectation)
--    - UNIQUE_COUNT on risk_tier       → (informational, no expectation)
--    - FRESHNESS on score_calculated_at → EXPECTATION: VALUE <= 86400 (24h)
--    - ROW_COUNT                        → EXPECTATION: VALUE >= 500
--
-- 2. CUSTOM DMFs Created with EXPECTATIONS:
--    - risk_score_out_of_range    → EXPECTATION: VALUE = 0
--    - risk_tier_misalignment     → EXPECTATION: VALUE = 0
--    - invalid_risk_tier          → EXPECTATION: VALUE = 0
--    - high_risk_percentage       → EXPECTATION: VALUE <= 35
--
-- 3. Native Features Used:
--    - EXPECTATION clause (native pass/fail evaluation)
--    - DATA_QUALITY_MONITORING_EXPECTATION_STATUS view
--    - SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS function
--    - DATA_QUALITY_MONITORING_RESULTS view
--    - DATA_METRIC_FUNCTION_REFERENCES
--    - ACCOUNT_USAGE.QUERY_HISTORY
--    - Snowflake ALERT objects
--
-- Docs: 
--   - https://docs.snowflake.com/en/user-guide/data-quality-intro
--   - https://docs.snowflake.com/en/user-guide/data-quality-expectations
-- ============================================================================


-- ============================================================================
-- PART 10: IMMEDIATE QUALITY TESTS (Run without waiting for DMF schedule)
-- ============================================================================
-- These queries test the same rules as DMFs but return results immediately.
-- Useful for validation during development or ad-hoc checks.
-- ============================================================================

-- 10a. Test: NULL checks on critical columns
SELECT 
    'NULL_COUNT' AS test_name,
    'customer_id' AS column_name,
    COUNT(*) - COUNT(customer_id) AS null_count,
    0 AS expectation,
    CASE WHEN COUNT(*) - COUNT(customer_id) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
UNION ALL
SELECT 
    'NULL_COUNT', 'churn_risk_score',
    COUNT(*) - COUNT(churn_risk_score), 0,
    CASE WHEN COUNT(*) - COUNT(churn_risk_score) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
UNION ALL
SELECT 
    'NULL_COUNT', 'risk_tier',
    COUNT(*) - COUNT(risk_tier), 0,
    CASE WHEN COUNT(*) - COUNT(risk_tier) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 10b. Test: DUPLICATE check on primary key
SELECT 
    'DUPLICATE_COUNT' AS test_name,
    'customer_id' AS column_name,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_count,
    0 AS expectation,
    CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN '✅ PASS' ELSE '❌ FAIL' END AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 10c. Test: ROW_COUNT minimum threshold
SELECT 
    'ROW_COUNT' AS test_name,
    'table' AS column_name,
    COUNT(*) AS row_count,
    500 AS expectation,
    CASE WHEN COUNT(*) >= 500 THEN '✅ PASS' ELSE '❌ FAIL' END AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 10d. Test: UNIQUE_COUNT cardinality
SELECT 
    'UNIQUE_COUNT' AS test_name,
    'customer_id' AS column_name,
    COUNT(DISTINCT customer_id) AS unique_count,
    NULL AS expectation,
    '✅ INFO' AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
UNION ALL
SELECT 
    'UNIQUE_COUNT', 'risk_tier',
    COUNT(DISTINCT risk_tier), NULL, '✅ INFO'
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 10e. Test: FRESHNESS (hours since last update)
SELECT 
    'FRESHNESS' AS test_name,
    'score_calculated_at' AS column_name,
    ROUND(DATEDIFF('second', MAX(score_calculated_at), CURRENT_TIMESTAMP()) / 3600.0, 1) AS hours_old,
    24 AS expectation_hours,
    CASE 
        WHEN DATEDIFF('second', MAX(score_calculated_at), CURRENT_TIMESTAMP()) <= 86400 THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 10f. Test: Risk score range (0-100)
SELECT 
    'RISK_SCORE_RANGE' AS test_name,
    'churn_risk_score' AS column_name,
    SUM(CASE WHEN churn_risk_score < 0 OR churn_risk_score > 100 THEN 1 ELSE 0 END) AS out_of_range,
    0 AS expectation,
    CASE 
        WHEN SUM(CASE WHEN churn_risk_score < 0 OR churn_risk_score > 100 THEN 1 ELSE 0 END) = 0 THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 10g. Test: Risk tier valid values
SELECT 
    'VALID_RISK_TIER' AS test_name,
    'risk_tier' AS column_name,
    SUM(CASE WHEN risk_tier NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS invalid_count,
    0 AS expectation,
    CASE 
        WHEN SUM(CASE WHEN risk_tier NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') THEN 1 ELSE 0 END) = 0 THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 10h. Test: Risk tier alignment with score
SELECT 
    'RISK_TIER_ALIGNMENT' AS test_name,
    'churn_risk_score, risk_tier' AS column_name,
    SUM(CASE 
        WHEN NOT (
            (churn_risk_score <= 25 AND risk_tier = 'LOW') OR
            (churn_risk_score > 25 AND churn_risk_score <= 50 AND risk_tier = 'MEDIUM') OR
            (churn_risk_score > 50 AND churn_risk_score <= 75 AND risk_tier = 'HIGH') OR
            (churn_risk_score > 75 AND risk_tier = 'CRITICAL')
        ) THEN 1 ELSE 0 END) AS misaligned_count,
    0 AS expectation,
    CASE 
        WHEN SUM(CASE 
            WHEN NOT (
                (churn_risk_score <= 25 AND risk_tier = 'LOW') OR
                (churn_risk_score > 25 AND churn_risk_score <= 50 AND risk_tier = 'MEDIUM') OR
                (churn_risk_score > 50 AND churn_risk_score <= 75 AND risk_tier = 'HIGH') OR
                (churn_risk_score > 75 AND risk_tier = 'CRITICAL')
            ) THEN 1 ELSE 0 END) = 0 THEN '✅ PASS'
        ELSE '❌ FAIL'
    END AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 10i. Test: High risk percentage (business threshold)
SELECT 
    'HIGH_RISK_PERCENTAGE' AS test_name,
    'risk_tier' AS column_name,
    ROUND(SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS high_risk_pct,
    35 AS expectation_max_pct,
    CASE 
        WHEN ROUND(SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) <= 35 THEN '✅ PASS'
        ELSE '⚠️ WARN'
    END AS result
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;


-- ============================================================================
-- COMBINED TEST SUMMARY (Run this for a quick overview)
-- ============================================================================

SELECT '══════════════════════════════════════════════════════════════' AS summary UNION ALL
SELECT '                    DATA QUALITY TEST RESULTS                  ' UNION ALL
SELECT '══════════════════════════════════════════════════════════════';

-- Run all tests and show summary
WITH all_tests AS (
    SELECT 'NULL_COUNT (customer_id)' AS test, 
           CASE WHEN COUNT(*) - COUNT(customer_id) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS result,
           COUNT(*) - COUNT(customer_id) AS value
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    UNION ALL
    SELECT 'NULL_COUNT (churn_risk_score)', 
           CASE WHEN COUNT(*) - COUNT(churn_risk_score) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END,
           COUNT(*) - COUNT(churn_risk_score)
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    UNION ALL
    SELECT 'NULL_COUNT (risk_tier)', 
           CASE WHEN COUNT(*) - COUNT(risk_tier) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END,
           COUNT(*) - COUNT(risk_tier)
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    UNION ALL
    SELECT 'DUPLICATE_COUNT (customer_id)', 
           CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN '✅ PASS' ELSE '❌ FAIL' END,
           COUNT(*) - COUNT(DISTINCT customer_id)
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    UNION ALL
    SELECT 'ROW_COUNT (>= 500)', 
           CASE WHEN COUNT(*) >= 500 THEN '✅ PASS' ELSE '❌ FAIL' END,
           COUNT(*)
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    UNION ALL
    SELECT 'RISK_SCORE_RANGE (0-100)', 
           CASE WHEN SUM(CASE WHEN churn_risk_score < 0 OR churn_risk_score > 100 THEN 1 ELSE 0 END) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END,
           SUM(CASE WHEN churn_risk_score < 0 OR churn_risk_score > 100 THEN 1 ELSE 0 END)
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    UNION ALL
    SELECT 'VALID_RISK_TIER', 
           CASE WHEN SUM(CASE WHEN risk_tier NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') THEN 1 ELSE 0 END) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END,
           SUM(CASE WHEN risk_tier NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') THEN 1 ELSE 0 END)
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    UNION ALL
    SELECT 'HIGH_RISK_PCT (<= 35%)', 
           CASE WHEN ROUND(SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) <= 35 THEN '✅ PASS' ELSE '⚠️ WARN' END,
           ROUND(SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
)
SELECT test, result, value FROM all_tests;


-- ============================================================================
-- OPTIONAL: MANUALLY TRIGGER SCHEDULED DMFs
-- ============================================================================
-- To force the scheduled DMFs to populate DATA_QUALITY_MONITORING_RESULTS:
-- Make a dummy update to trigger TRIGGER_ON_CHANGES (if using that schedule):
--
-- UPDATE RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK 
-- SET score_calculated_at = score_calculated_at 
-- WHERE 1=0;
--
-- Then query: SELECT * FROM MONITORING.data_quality_results;
