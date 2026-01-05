# 00_setup - Snowflake Setup Scripts

This folder contains SQL scripts to set up the Data Products demo environment in Snowflake using **Git Integration**.

## Overview

With Snowflake Git Integration, you can:
- Connect directly to this GitHub repository
- Run SQL scripts from the repo without downloading
- Keep your Snowflake environment in sync with Git
- Deploy Streamlit apps directly from Git

## Setup Scripts

Run these scripts in order:

| Script | Purpose |
|--------|---------|
| `01_git_integration.sql` | Create Git integration and connect to repository |
| `02_run_setup_from_git.sql` | Run all setup scripts from Git |
| `03_deploy_streamlit_app.sql` | Deploy the dbt Code Generator app |

## Quick Start

### Step 1: Create Git Integration

```sql
-- Run in Snowflake Snowsight
-- Copy and execute: 01_git_integration.sql

-- This creates:
-- • Git API integration
-- • Database and schemas
-- • Git repository connection
```

### Step 2: Run Complete Setup

```sql
-- Run in Snowflake Snowsight
-- Copy and execute: 02_run_setup_from_git.sql

-- This executes (from Git):
-- • 03_deliver/03a_create_sample_data.sql
-- • 03_deliver/03c_output_examples/retail_customer_churn_risk.sql
-- • 03_deliver/03c_output_examples/masking_policies.sql
-- • 03_deliver/03c_output_examples/business_rules_tests.sql
-- • 04_operate/monitoring_observability.sql
```

### Step 3: Deploy Streamlit App (Optional)

```sql
-- Run in Snowflake Snowsight
-- Copy and execute: 03_deploy_streamlit_app.sql

-- This creates:
-- • Streamlit app from Git
-- • Contract upload stage
```

## What Gets Created

```
RETAIL_BANKING_DB/
├── RAW/                          # Source data
│   ├── CUSTOMERS
│   ├── ACCOUNTS
│   ├── TRANSACTIONS
│   ├── DIGITAL_ENGAGEMENT
│   └── COMPLAINTS
├── DATA_PRODUCTS/                # Data products
│   └── RETAIL_CUSTOMER_CHURN_RISK
├── GOVERNANCE/                   # Git & contracts
│   ├── data_products_repo        # Git repository
│   └── data_contracts/           # Contract stage
├── MONITORING/                   # Observability
│   ├── data_quality_log
│   ├── data_freshness_status
│   └── data_product_health_summary
└── Streamlit Apps
    └── dbt_code_generator
```

## Useful Commands

```sql
-- Refresh from Git
ALTER GIT REPOSITORY GOVERNANCE.data_products_repo FETCH;

-- List files in repo
LS @GOVERNANCE.data_products_repo/branches/main/;

-- View a file from Git
SELECT $1 FROM @GOVERNANCE.data_products_repo/branches/main/02_design/churn_risk_data_contract.yaml
(FILE_FORMAT => (TYPE = 'CSV' FIELD_DELIMITER = NONE));

-- Run a script from Git
EXECUTE IMMEDIATE FROM @GOVERNANCE.data_products_repo/branches/main/03_deliver/03a_create_sample_data.sql;
```

## Prerequisites

- Snowflake account with ACCOUNTADMIN role
- COMPUTE_WH warehouse (or equivalent)
- For private repos: GitHub Personal Access Token

## Troubleshooting

### "API Integration not found"
Run `01_git_integration.sql` first to create the API integration.

### "Git repository fetch failed"
Check that:
1. The repository URL is correct
2. For private repos, the secret is configured correctly
3. Network policies allow GitHub access

### "Streamlit app won't start"
Verify:
1. COMPUTE_WH warehouse exists and is running
2. You have USAGE privilege on the Streamlit
3. Cortex functions are enabled (for LLM features)

