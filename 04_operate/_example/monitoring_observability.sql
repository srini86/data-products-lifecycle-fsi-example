-- ============================================================================
-- OPERATE: Monitoring & Observability for Data Products
-- ============================================================================
-- Once data products are live, the work shifts from building to running them
-- well. Operate is about making sure each product continues to meet its
-- contract in the real world.
--
-- For regulated industries, this phase is crucial. This script focuses on:
--   1. RELIABILITY: Are freshness and availability SLAs being met?
--   2. QUALITY & COMPLIANCE: Are quality rules holding? Access controls correct?
--   3. ADOPTION & IMPACT: Who is using the product, and how?
--
-- Prerequisites: Run 03_deliver/02_data_quality_dmf.sql first to set up DMFs.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RETAIL_BANKING_DB;

-- Create monitoring schema for dashboards and alerts
CREATE SCHEMA IF NOT EXISTS MONITORING;
USE SCHEMA MONITORING;


-- ============================================================================
-- PART 1: RELIABILITY MONITORING
-- ============================================================================
-- Are freshness and availability SLAs being met?
-- Are there failed loads, late runs, or unexpected gaps?
-- ============================================================================

-- 1a. Check current freshness status (SLA: 24 hours)
SELECT 
    'FRESHNESS CHECK' AS check_type,
    DATEDIFF('hour', MAX(score_calculated_at), CURRENT_TIMESTAMP()) AS hours_since_refresh,
    CASE 
        WHEN DATEDIFF('hour', MAX(score_calculated_at), CURRENT_TIMESTAMP()) <= 24 
        THEN '✅ WITHIN SLA' 
        ELSE '❌ SLA BREACH' 
    END AS sla_status,
    MAX(score_calculated_at) AS last_refresh,
    '24 hours' AS sla_target
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;


-- 1b. Freshness history from DMF results (trend over time)
SELECT 
    DATE_TRUNC('hour', measurement_time) AS check_time,
    value AS freshness_seconds,
    ROUND(value / 3600, 1) AS freshness_hours,
    CASE WHEN value <= 86400 THEN '✅ OK' ELSE '❌ BREACH' END AS status
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
  AND metric_name = 'FRESHNESS'
ORDER BY measurement_time DESC
LIMIT 48;  -- Last 24 hours of checks (every 30 min)


-- 1c. Row count stability (detect unexpected data drops)
SELECT 
    DATE_TRUNC('hour', measurement_time) AS check_time,
    value AS row_count,
    LAG(value) OVER (ORDER BY measurement_time) AS prev_row_count,
    ROUND(((value - LAG(value) OVER (ORDER BY measurement_time)) / 
           NULLIF(LAG(value) OVER (ORDER BY measurement_time), 0)) * 100, 1) AS pct_change,
    CASE 
        WHEN ABS(((value - LAG(value) OVER (ORDER BY measurement_time)) / 
                  NULLIF(LAG(value) OVER (ORDER BY measurement_time), 0)) * 100) > 20 
        THEN '⚠️ SIGNIFICANT CHANGE'
        ELSE '✅ STABLE'
    END AS status
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
  AND metric_name = 'ROW_COUNT'
ORDER BY measurement_time DESC
LIMIT 20;


-- 1d. Data availability check (is the table accessible?)
SELECT 
    'DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK' AS table_name,
    COUNT(*) AS current_row_count,
    MAX(data_as_of_date) AS data_as_of,
    MAX(score_calculated_at) AS last_calculated,
    CASE WHEN COUNT(*) > 0 THEN '✅ AVAILABLE' ELSE '❌ UNAVAILABLE' END AS availability
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;


-- ============================================================================
-- PART 2: QUALITY & COMPLIANCE MONITORING  
-- ============================================================================
-- Are key data quality rules holding (value ranges, uniqueness, completeness)?
-- Are access controls, masking, and classifications correctly applied?
-- Can we explain lineage end-to-end?
-- ============================================================================

-- 2a. Overall expectation status (are contract quality rules passing?)
SELECT 
    expectation_name,
    CASE status 
        WHEN 'PASSED' THEN '✅ PASSED'
        WHEN 'FAILED' THEN '❌ FAILED'
        ELSE '⚠️ ' || status
    END AS status,
    metric_name,
    metric_value,
    measurement_time
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
ORDER BY measurement_time DESC, expectation_name
LIMIT 50;


-- 2b. Quality summary dashboard
SELECT 
    metric_name,
    argument_names AS columns,
    value AS current_value,
    measurement_time AS last_checked
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
  AND measurement_time = (
      SELECT MAX(measurement_time) 
      FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS 
      WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
  )
ORDER BY metric_name;


-- 2c. Failed expectations history (quality violations over time)
SELECT 
    DATE(measurement_time) AS date,
    expectation_name,
    status,
    metric_value,
    COUNT(*) AS occurrence_count
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
  AND status = 'FAILED'
GROUP BY DATE(measurement_time), expectation_name, status, metric_value
ORDER BY date DESC, expectation_name;


-- 2d. Verify masking policies are applied (compliance check)
SELECT 
    policy_name,
    policy_kind,
    ref_entity_name AS applied_to_table,
    ref_column_name AS masked_column,
    policy_status
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    REF_ENTITY_NAME => 'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK',
    REF_ENTITY_DOMAIN => 'TABLE'
))
WHERE policy_kind = 'MASKING_POLICY';


-- 2e. Verify tags and classifications (governance metadata)
SELECT 
    tag_database,
    tag_schema,
    tag_name,
    tag_value,
    column_name,
    object_name AS table_name
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES(
    'RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK', 
    'TABLE'
));


-- 2f. Data lineage - upstream dependencies (where does data come from?)
-- Note: Requires ACCESS_HISTORY to be enabled
SELECT DISTINCT
    directSources.value:objectName::STRING AS source_object,
    directSources.value:objectDomain::STRING AS source_type,
    'RETAIL_CUSTOMER_CHURN_RISK' AS target_table
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY,
    LATERAL FLATTEN(input => direct_objects_accessed) AS directSources
WHERE query_start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND ARRAY_CONTAINS('RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'::VARIANT, 
                     base_objects_accessed)
LIMIT 20;


-- ============================================================================
-- PART 3: ADOPTION & IMPACT MONITORING
-- ============================================================================
-- Who is using the product, and how?
-- Which models, dashboards, and processes depend on it?
-- Are the agreed KPIs actually improving over time?
-- ============================================================================

-- 3a. Usage by role (who is consuming the data product?)
SELECT 
    role_name,
    COUNT(*) AS query_count,
    COUNT(DISTINCT user_name) AS unique_users,
    COUNT(DISTINCT DATE(query_start_time)) AS active_days,
    MIN(query_start_time) AS first_access,
    MAX(query_start_time) AS last_access
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time > DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND ARRAY_CONTAINS('RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'::VARIANT, 
                     base_objects_accessed)
GROUP BY role_name
ORDER BY query_count DESC;


-- 3b. Usage by user (individual consumer activity)
SELECT 
    user_name,
    role_name,
    COUNT(*) AS query_count,
    MAX(query_start_time) AS last_access,
    DATEDIFF('day', MAX(query_start_time), CURRENT_TIMESTAMP()) AS days_since_last_access
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time > DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND ARRAY_CONTAINS('RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'::VARIANT, 
                     base_objects_accessed)
GROUP BY user_name, role_name
ORDER BY query_count DESC
LIMIT 20;


-- 3c. Daily usage trend (adoption over time)
SELECT 
    DATE(query_start_time) AS date,
    COUNT(*) AS query_count,
    COUNT(DISTINCT user_name) AS unique_users,
    COUNT(DISTINCT role_name) AS unique_roles
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time > DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND ARRAY_CONTAINS('RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'::VARIANT, 
                     base_objects_accessed)
GROUP BY DATE(query_start_time)
ORDER BY date DESC;


-- 3d. Query patterns (what columns/features are most used?)
SELECT 
    objects_accessed.value:objectName::STRING AS accessed_object,
    objects_accessed.value:columns AS columns_accessed,
    COUNT(*) AS access_count
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY,
    LATERAL FLATTEN(input => direct_objects_accessed) AS objects_accessed
WHERE query_start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND objects_accessed.value:objectName::STRING LIKE '%RETAIL_CUSTOMER_CHURN_RISK%'
GROUP BY objects_accessed.value:objectName::STRING, objects_accessed.value:columns
ORDER BY access_count DESC
LIMIT 20;


-- 3e. Downstream dependencies (what depends on this data product?)
SELECT DISTINCT
    query_text,
    user_name,
    role_name,
    query_start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE query_start_time > DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND ARRAY_CONTAINS('RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'::VARIANT, 
                     base_objects_accessed)
  AND (UPPER(query_text) LIKE '%CREATE%VIEW%' 
       OR UPPER(query_text) LIKE '%CREATE%TABLE%'
       OR UPPER(query_text) LIKE '%INSERT%INTO%')
ORDER BY query_start_time DESC
LIMIT 10;


-- ============================================================================
-- PART 4: ALERTING SETUP
-- ============================================================================
-- Proactive notifications for SLA breaches and quality violations.
-- Contract-driven pipelines make this easier because expectations are codified.
-- ============================================================================

-- 4a. Create alert for freshness SLA breach (data older than 24 hours)
CREATE OR REPLACE ALERT MONITORING.freshness_sla_alert
    WAREHOUSE = DATA_PRODUCTS_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Check every hour
    IF (EXISTS (
        SELECT 1 
        FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
        WHERE DATEDIFF('hour', score_calculated_at, CURRENT_TIMESTAMP()) > 24
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'data_product_alerts',
            'data-products-team@company.com',
            '🚨 Churn Risk Data Product: Freshness SLA Breach',
            'The Retail Customer Churn Risk data product has not been refreshed in over 24 hours. Please investigate the pipeline.'
        );

-- 4b. Create alert for quality expectation failures
CREATE OR REPLACE ALERT MONITORING.quality_expectation_alert
    WAREHOUSE = DATA_PRODUCTS_WH
    SCHEDULE = 'USING CRON 30 * * * * UTC'  -- Check every hour at :30
    IF (EXISTS (
        SELECT 1 
        FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
        WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
          AND status = 'FAILED'
          AND measurement_time > DATEADD('hour', -1, CURRENT_TIMESTAMP())
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'data_product_alerts',
            'data-products-team@company.com',
            '🚨 Churn Risk Data Product: Quality Expectation Failed',
            'One or more data quality expectations have failed for the Retail Customer Churn Risk data product. Check the Data Quality dashboard in Snowsight.'
        );

-- 4c. Create alert for significant row count changes (>20% drop)
CREATE OR REPLACE ALERT MONITORING.row_count_anomaly_alert
    WAREHOUSE = DATA_PRODUCTS_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'  -- Check daily at 6 AM UTC
    IF (EXISTS (
        WITH row_counts AS (
            SELECT 
                value AS row_count,
                LAG(value) OVER (ORDER BY measurement_time) AS prev_row_count
            FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
            WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
              AND metric_name = 'ROW_COUNT'
            ORDER BY measurement_time DESC
            LIMIT 2
        )
        SELECT 1 FROM row_counts
        WHERE prev_row_count > 0 
          AND ((prev_row_count - row_count) / prev_row_count) > 0.2
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'data_product_alerts',
            'data-products-team@company.com',
            '🚨 Churn Risk Data Product: Significant Row Count Drop',
            'The Retail Customer Churn Risk data product has experienced a >20% drop in row count. This may indicate a failed load or data issue.'
        );

-- Enable the alerts
ALTER ALERT MONITORING.freshness_sla_alert RESUME;
ALTER ALERT MONITORING.quality_expectation_alert RESUME;
ALTER ALERT MONITORING.row_count_anomaly_alert RESUME;


-- ============================================================================
-- PART 5: OPERATIONAL DASHBOARD VIEW
-- ============================================================================
-- Create a unified view for operational monitoring dashboards.
-- ============================================================================

CREATE OR REPLACE VIEW MONITORING.data_product_health_summary AS
WITH freshness AS (
    SELECT 
        DATEDIFF('hour', MAX(score_calculated_at), CURRENT_TIMESTAMP()) AS hours_since_refresh,
        CASE 
            WHEN DATEDIFF('hour', MAX(score_calculated_at), CURRENT_TIMESTAMP()) <= 24 
            THEN 'OK' ELSE 'BREACH' 
        END AS freshness_status
    FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
),
quality AS (
    SELECT 
        COUNT(CASE WHEN status = 'FAILED' THEN 1 END) AS failed_expectations,
        COUNT(*) AS total_expectations
    FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS
    WHERE table_name = 'RETAIL_CUSTOMER_CHURN_RISK'
      AND measurement_time > DATEADD('hour', -1, CURRENT_TIMESTAMP())
),
usage AS (
    SELECT 
        COUNT(*) AS queries_last_24h,
        COUNT(DISTINCT user_name) AS unique_users_last_24h
    FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
    WHERE query_start_time > DATEADD('day', -1, CURRENT_TIMESTAMP())
      AND ARRAY_CONTAINS('RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK'::VARIANT, 
                         base_objects_accessed)
)
SELECT 
    'RETAIL_CUSTOMER_CHURN_RISK' AS data_product,
    f.hours_since_refresh,
    f.freshness_status,
    q.failed_expectations,
    q.total_expectations,
    CASE WHEN q.failed_expectations = 0 THEN 'OK' ELSE 'ISSUES' END AS quality_status,
    u.queries_last_24h,
    u.unique_users_last_24h,
    CURRENT_TIMESTAMP() AS checked_at
FROM freshness f, quality q, usage u;

-- View the health summary
SELECT * FROM MONITORING.data_product_health_summary;


-- ============================================================================
-- OPERATE PHASE COMPLETE
-- ============================================================================
-- This script sets up ongoing monitoring for a live data product.
-- 
-- Reliability:
--   • Freshness SLA tracking (24-hour target)
--   • Row count stability monitoring
--   • Data availability checks
--
-- Quality & Compliance:
--   • DMF expectation status monitoring
--   • Masking policy verification
--   • Tag/classification checks
--   • Lineage visibility
--
-- Adoption & Impact:
--   • Usage by role and user
--   • Daily usage trends
--   • Query patterns analysis
--   • Downstream dependency tracking
--
-- Alerting:
--   • Freshness SLA breach alerts
--   • Quality expectation failure alerts
--   • Row count anomaly alerts
--
-- View results: 
--   • Snowsight → Data → Databases → RETAIL_BANKING_DB → DATA_PRODUCTS → 
--     RETAIL_CUSTOMER_CHURN_RISK → Data Quality tab
--   • Query MONITORING.data_product_health_summary for dashboard
-- ============================================================================
