-- ============================================================================
-- OPERATE: Monitoring & Observability for Retail Customer Churn Risk
-- ============================================================================
-- This script sets up monitoring and observability for the data product:
-- 1. Data quality checks
-- 2. SLA monitoring (freshness, availability)
-- 3. Usage telemetry
-- 4. Alerting via Snowflake Tasks and Notifications
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;

-- Create monitoring schema
CREATE SCHEMA IF NOT EXISTS MONITORING;
USE SCHEMA MONITORING;

-- ============================================================================
-- PART 1: DATA QUALITY MONITORING
-- ============================================================================

-- 1a. Create a table to store data quality check results
CREATE OR REPLACE TABLE data_quality_log (
    check_id            VARCHAR(50) DEFAULT UUID_STRING(),
    check_timestamp     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    data_product_name   VARCHAR(200),
    check_type          VARCHAR(100),
    check_name          VARCHAR(200),
    check_status        VARCHAR(20),  -- PASS, FAIL, WARN
    expected_value      VARCHAR(500),
    actual_value        VARCHAR(500),
    details             VARIANT,
    PRIMARY KEY (check_id)
);

-- 1b. Stored procedure to run data quality checks
CREATE OR REPLACE PROCEDURE run_data_quality_checks(data_product_name VARCHAR)
RETURNS TABLE (check_name VARCHAR, status VARCHAR, details VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result_cursor CURSOR FOR 
        SELECT check_name, check_status, actual_value 
        FROM MONITORING.data_quality_log 
        WHERE data_product_name = :data_product_name
        AND check_timestamp > DATEADD('hour', -1, CURRENT_TIMESTAMP())
        ORDER BY check_timestamp DESC;
BEGIN
    -- Check 1: Row count threshold
    INSERT INTO MONITORING.data_quality_log 
        (data_product_name, check_type, check_name, check_status, expected_value, actual_value)
    SELECT 
        :data_product_name,
        'COMPLETENESS',
        'Row Count Threshold',
        CASE WHEN COUNT(*) >= 500 THEN 'PASS' ELSE 'FAIL' END,
        '>= 500',
        COUNT(*)::VARCHAR
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;
    
    -- Check 2: Primary key uniqueness
    INSERT INTO MONITORING.data_quality_log 
        (data_product_name, check_type, check_name, check_status, expected_value, actual_value)
    SELECT 
        :data_product_name,
        'UNIQUENESS',
        'Customer ID Uniqueness',
        CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'PASS' ELSE 'FAIL' END,
        '100% unique',
        ROUND(COUNT(DISTINCT customer_id) * 100.0 / NULLIF(COUNT(*), 0), 2)::VARCHAR || '%'
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;
    
    -- Check 3: Null check on critical columns
    INSERT INTO MONITORING.data_quality_log 
        (data_product_name, check_type, check_name, check_status, expected_value, actual_value)
    SELECT 
        :data_product_name,
        'COMPLETENESS',
        'Churn Risk Score Not Null',
        CASE WHEN SUM(CASE WHEN churn_risk_score IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0 nulls',
        SUM(CASE WHEN churn_risk_score IS NULL THEN 1 ELSE 0 END)::VARCHAR || ' nulls'
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;
    
    -- Check 4: Value range for risk score
    INSERT INTO MONITORING.data_quality_log 
        (data_product_name, check_type, check_name, check_status, expected_value, actual_value)
    SELECT 
        :data_product_name,
        'VALIDITY',
        'Risk Score Range (0-100)',
        CASE 
            WHEN MIN(churn_risk_score) >= 0 AND MAX(churn_risk_score) <= 100 THEN 'PASS' 
            ELSE 'FAIL' 
        END,
        '0 to 100',
        'Min: ' || MIN(churn_risk_score)::VARCHAR || ', Max: ' || MAX(churn_risk_score)::VARCHAR
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;
    
    -- Check 5: Risk tier alignment with score
    INSERT INTO MONITORING.data_quality_log 
        (data_product_name, check_type, check_name, check_status, expected_value, actual_value)
    SELECT 
        :data_product_name,
        'BUSINESS_RULE',
        'Risk Tier Aligns with Score',
        CASE WHEN misaligned_count = 0 THEN 'PASS' ELSE 'FAIL' END,
        '0 misaligned',
        misaligned_count::VARCHAR || ' misaligned'
    FROM (
        SELECT COUNT(*) AS misaligned_count
        FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
        WHERE NOT (
            (churn_risk_score <= 25 AND risk_tier = 'LOW') OR
            (churn_risk_score > 25 AND churn_risk_score <= 50 AND risk_tier = 'MEDIUM') OR
            (churn_risk_score > 50 AND churn_risk_score <= 75 AND risk_tier = 'HIGH') OR
            (churn_risk_score > 75 AND risk_tier = 'CRITICAL')
        )
    );
    
    -- Check 6: High risk percentage threshold (warn if >25%)
    INSERT INTO MONITORING.data_quality_log 
        (data_product_name, check_type, check_name, check_status, expected_value, actual_value)
    SELECT 
        :data_product_name,
        'BUSINESS_RULE',
        'High Risk Percentage',
        CASE 
            WHEN high_risk_pct <= 25 THEN 'PASS' 
            WHEN high_risk_pct <= 35 THEN 'WARN'
            ELSE 'FAIL' 
        END,
        '<= 25%',
        ROUND(high_risk_pct, 2)::VARCHAR || '%'
    FROM (
        SELECT 
            SUM(CASE WHEN risk_tier IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS high_risk_pct
        FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
    );
    
    -- Return results
    OPEN result_cursor;
    RETURN TABLE(result_cursor);
END;
$$;


-- ============================================================================
-- PART 2: SLA MONITORING
-- ============================================================================

-- 2a. Freshness monitoring view
CREATE OR REPLACE VIEW data_freshness_status AS
SELECT 
    'RETAIL_CUSTOMER_CHURN_RISK' AS data_product_name,
    MAX(score_calculated_at) AS last_refresh_time,
    MAX(data_as_of_date) AS data_as_of_date,
    DATEDIFF('hour', MAX(score_calculated_at), CURRENT_TIMESTAMP()) AS hours_since_refresh,
    CASE 
        WHEN DATEDIFF('hour', MAX(score_calculated_at), CURRENT_TIMESTAMP()) <= 24 THEN 'FRESH'
        WHEN DATEDIFF('hour', MAX(score_calculated_at), CURRENT_TIMESTAMP()) <= 25 THEN 'WARNING'
        ELSE 'STALE'
    END AS freshness_status,
    '24 hours' AS sla_threshold,
    CASE 
        WHEN DATEDIFF('hour', MAX(score_calculated_at), CURRENT_TIMESTAMP()) <= 24 THEN 'MEETING_SLA'
        ELSE 'SLA_BREACH'
    END AS sla_status
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- 2b. SLA tracking table
CREATE OR REPLACE TABLE sla_tracking (
    tracking_id         VARCHAR(50) DEFAULT UUID_STRING(),
    check_timestamp     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    data_product_name   VARCHAR(200),
    sla_type            VARCHAR(50),  -- FRESHNESS, AVAILABILITY, RESPONSE_TIME
    sla_target          VARCHAR(100),
    actual_value        VARCHAR(100),
    sla_met             BOOLEAN,
    breach_duration_minutes INTEGER,
    PRIMARY KEY (tracking_id)
);

-- 2c. Procedure to check and log SLA status
CREATE OR REPLACE PROCEDURE check_sla_status()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Log freshness SLA
    INSERT INTO MONITORING.sla_tracking 
        (data_product_name, sla_type, sla_target, actual_value, sla_met, breach_duration_minutes)
    SELECT 
        data_product_name,
        'FRESHNESS',
        sla_threshold,
        hours_since_refresh::VARCHAR || ' hours',
        sla_status = 'MEETING_SLA',
        CASE 
            WHEN sla_status = 'MEETING_SLA' THEN 0 
            ELSE (hours_since_refresh - 24) * 60 
        END
    FROM MONITORING.data_freshness_status;
    
    RETURN 'SLA check completed';
END;
$$;


-- ============================================================================
-- PART 3: USAGE TELEMETRY
-- ============================================================================

-- 3a. Query history for the data product
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
    query_type,
    CASE 
        WHEN query_text ILIKE '%RETAIL_CUSTOMER_CHURN_RISK%' THEN 'CHURN_RISK_PRODUCT'
        ELSE 'OTHER'
    END AS data_product_accessed
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%RETAIL_CUSTOMER_CHURN_RISK%'
  AND start_time >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY start_time DESC;

-- 3b. Usage summary by consumer
CREATE OR REPLACE VIEW usage_by_consumer AS
SELECT 
    user_name,
    role_name,
    COUNT(*) AS query_count,
    SUM(rows_produced) AS total_rows_accessed,
    AVG(duration_seconds) AS avg_query_duration_sec,
    MIN(start_time) AS first_access,
    MAX(start_time) AS last_access
FROM MONITORING.data_product_usage
WHERE data_product_accessed = 'CHURN_RISK_PRODUCT'
GROUP BY user_name, role_name
ORDER BY query_count DESC;

-- 3c. Daily usage trends
CREATE OR REPLACE VIEW daily_usage_trends AS
SELECT 
    DATE(start_time) AS usage_date,
    COUNT(*) AS query_count,
    COUNT(DISTINCT user_name) AS unique_users,
    SUM(rows_produced) AS total_rows,
    AVG(duration_seconds) AS avg_duration_sec
FROM MONITORING.data_product_usage
WHERE data_product_accessed = 'CHURN_RISK_PRODUCT'
GROUP BY DATE(start_time)
ORDER BY usage_date DESC;


-- ============================================================================
-- PART 4: DATA PRODUCT METRICS DASHBOARD
-- ============================================================================

-- 4a. Executive summary view
CREATE OR REPLACE VIEW data_product_health_summary AS
SELECT 
    'RETAIL_CUSTOMER_CHURN_RISK' AS data_product_name,
    
    -- Row count
    (SELECT COUNT(*) FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK) AS total_records,
    
    -- Freshness
    (SELECT freshness_status FROM MONITORING.data_freshness_status) AS freshness_status,
    (SELECT hours_since_refresh FROM MONITORING.data_freshness_status) AS hours_since_refresh,
    
    -- Latest DQ status
    (SELECT COUNT(*) FROM MONITORING.data_quality_log 
     WHERE data_product_name = 'RETAIL_CUSTOMER_CHURN_RISK' 
       AND check_status = 'PASS'
       AND check_timestamp > DATEADD('day', -1, CURRENT_TIMESTAMP())) AS dq_checks_passed_24h,
    
    (SELECT COUNT(*) FROM MONITORING.data_quality_log 
     WHERE data_product_name = 'RETAIL_CUSTOMER_CHURN_RISK' 
       AND check_status = 'FAIL'
       AND check_timestamp > DATEADD('day', -1, CURRENT_TIMESTAMP())) AS dq_checks_failed_24h,
    
    -- Usage stats (last 7 days)
    (SELECT COUNT(*) FROM MONITORING.data_product_usage 
     WHERE data_product_accessed = 'CHURN_RISK_PRODUCT'
       AND start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())) AS queries_last_7d,
    
    (SELECT COUNT(DISTINCT user_name) FROM MONITORING.data_product_usage 
     WHERE data_product_accessed = 'CHURN_RISK_PRODUCT'
       AND start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())) AS unique_users_7d,
    
    CURRENT_TIMESTAMP() AS report_generated_at;

-- 4b. Risk distribution summary
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
-- PART 5: AUTOMATED MONITORING TASKS
-- ============================================================================

-- 5a. Create a task for daily data quality checks
CREATE OR REPLACE TASK daily_data_quality_check
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 7 * * * UTC'  -- Run daily at 7 AM UTC (after refresh)
AS
    CALL MONITORING.run_data_quality_checks('RETAIL_CUSTOMER_CHURN_RISK');

-- 5b. Create a task for hourly SLA monitoring
CREATE OR REPLACE TASK hourly_sla_check
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Run every hour
AS
    CALL MONITORING.check_sla_status();

-- 5c. Enable the tasks
ALTER TASK daily_data_quality_check RESUME;
ALTER TASK hourly_sla_check RESUME;


-- ============================================================================
-- PART 6: ALERTING SETUP
-- ============================================================================

-- 6a. Create email notification integration (requires account admin)
-- Note: Replace with your actual email integration settings
/*
CREATE OR REPLACE NOTIFICATION INTEGRATION data_product_alerts
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('retail-data-support@bank.com', 'alex.morgan@bank.com');
*/

-- 6b. Create alert for data freshness breach
CREATE OR REPLACE ALERT freshness_breach_alert
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Check every hour
    IF (EXISTS (
        SELECT 1 FROM MONITORING.data_freshness_status 
        WHERE freshness_status = 'STALE'
    ))
    THEN
        -- In production, this would send a notification
        -- For now, log to a table
        INSERT INTO MONITORING.sla_tracking 
            (data_product_name, sla_type, sla_target, actual_value, sla_met)
        SELECT 
            data_product_name, 
            'FRESHNESS_ALERT', 
            sla_threshold, 
            hours_since_refresh::VARCHAR || ' hours',
            FALSE
        FROM MONITORING.data_freshness_status;

-- 6c. Create alert for data quality failures
CREATE OR REPLACE ALERT dq_failure_alert
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 30 7 * * * UTC'  -- Check 30 mins after DQ runs
    IF (EXISTS (
        SELECT 1 FROM MONITORING.data_quality_log 
        WHERE data_product_name = 'RETAIL_CUSTOMER_CHURN_RISK'
          AND check_status = 'FAIL'
          AND check_timestamp > DATEADD('hour', -1, CURRENT_TIMESTAMP())
    ))
    THEN
        INSERT INTO MONITORING.sla_tracking 
            (data_product_name, sla_type, sla_target, actual_value, sla_met)
        VALUES 
            ('RETAIL_CUSTOMER_CHURN_RISK', 'DATA_QUALITY_ALERT', 'All checks pass', 'Failures detected', FALSE);

-- Enable alerts
ALTER ALERT freshness_breach_alert RESUME;
ALTER ALERT dq_failure_alert RESUME;


-- ============================================================================
-- PART 7: SAMPLE MONITORING QUERIES
-- ============================================================================

-- View overall health status
SELECT * FROM MONITORING.data_product_health_summary;

-- View recent data quality check results
SELECT 
    check_timestamp,
    check_type,
    check_name,
    check_status,
    expected_value,
    actual_value
FROM MONITORING.data_quality_log
WHERE data_product_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY check_timestamp DESC
LIMIT 20;

-- View freshness status
SELECT * FROM MONITORING.data_freshness_status;

-- View SLA tracking history
SELECT 
    check_timestamp,
    sla_type,
    sla_target,
    actual_value,
    sla_met,
    breach_duration_minutes
FROM MONITORING.sla_tracking
WHERE data_product_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY check_timestamp DESC
LIMIT 50;

-- View usage trends
SELECT * FROM MONITORING.daily_usage_trends LIMIT 30;

-- View top consumers
SELECT * FROM MONITORING.usage_by_consumer LIMIT 20;


-- ============================================================================
-- MONITORING SETUP COMPLETE
-- ============================================================================
-- Summary:
-- 1. Data quality checks configured (6 checks)
-- 2. Freshness monitoring enabled
-- 3. Usage telemetry views created
-- 4. Automated tasks scheduled
-- 5. Alerts configured for SLA breaches
-- ============================================================================

