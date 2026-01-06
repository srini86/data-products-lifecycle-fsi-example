# 00_setup - Snowflake Setup Scripts

This folder contains the setup script to deploy the dbt Code Generator Streamlit app.

## Quick Start

### Step 1: Run the Setup Script

Open `01_deploy_streamlit_app.sql` in Snowflake Snowsight and run Steps 1-2 to create the database, schemas, and stages.

### Step 2: Upload Files

Upload these files to Snowflake stages:

| File | Upload To Stage |
|------|-----------------|
| `02_design/churn_risk_data_contract.yaml` | `@GOVERNANCE.data_contracts` |
| `03_deliver/02_dbt_generator_app.py` | `@GOVERNANCE.streamlit_apps` |

**Using Snowsight (Web UI):**
1. Go to Data → Databases → RETAIL_BANKING_DB → GOVERNANCE → Stages
2. Click on stage → "+ Files" → Upload

**Using SnowSQL:**
```bash
snowsql -a <account> -u <username>

PUT file://02_design/churn_risk_data_contract.yaml @RETAIL_BANKING_DB.GOVERNANCE.data_contracts AUTO_COMPRESS=FALSE;
PUT file://03_deliver/02_dbt_generator_app.py @RETAIL_BANKING_DB.GOVERNANCE.streamlit_apps AUTO_COMPRESS=FALSE;
```

### Step 3: Deploy Streamlit App

Run Steps 5-6 in `01_deploy_streamlit_app.sql` to create and verify the Streamlit app.

## What Gets Created

```
RETAIL_BANKING_DB/
├── RAW/                          # Source data (created by 03a_create_sample_data.sql)
├── DATA_PRODUCTS/                # Data products
├── GOVERNANCE/                   # Governance artifacts
│   ├── data_contracts/           # Stage for contract YAMLs
│   └── streamlit_apps/           # Stage for Streamlit apps
└── Streamlit Apps
    └── dbt_code_generator        # The code generator app
```

## Using the App

1. Open the Streamlit app URL
2. Paste the data contract YAML or load from stage
3. Click "Generate All Outputs"
4. Download: `model.sql`, `schema.yml`, `masking_policies.sql`
