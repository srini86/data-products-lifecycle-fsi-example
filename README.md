# 🏦 Data Products for Financial Services

> A complete code sample demonstrating how to build, deliver, and operate Data Products for FSI using Snowflake.

[![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?logo=snowflake&logoColor=white)](https://snowflake.com)
[![dbt](https://img.shields.io/badge/dbt-FF694B?logo=dbt&logoColor=white)](https://getdbt.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

---

## 🚀 Quick Start

### Step 1: Clone & Setup

```bash
git clone https://github.com/sfc-gh-skuppusamy/data-products-code-sample
cd data-products-code-sample
```

Run in **Snowsight** or **SnowSQL** as `ACCOUNTADMIN`:

```sql
-- Creates database, sample data, stages, and Streamlit app
@setup.sql
```

### Step 2: Upload Files to Stages

After running `setup.sql`, upload these files using Snowsight:

| File | Upload To |
|------|-----------|
| `02_design/churn_risk_data_contract.yaml` | Stages → `DATA_CONTRACTS` → "+ Files" |
| `03_deliver/01_dbt_generator_app.py` | Stages → `STREAMLIT_APPS` → "+ Files" |

Or use SnowSQL:
```bash
PUT file://02_design/churn_risk_data_contract.yaml @RETAIL_BANKING_DB.GOVERNANCE.data_contracts AUTO_COMPRESS=FALSE;
PUT file://03_deliver/01_dbt_generator_app.py @RETAIL_BANKING_DB.GOVERNANCE.streamlit_apps AUTO_COMPRESS=FALSE;
```

### Step 3: Generate Code via Streamlit App

1. Open **Snowsight** → **Projects** → **Streamlit** → `dbt_code_generator`
2. Select `churn_risk_data_contract.yaml` from the stage dropdown
3. Click **Generate All Outputs**
4. Download/copy the generated `model.sql`

### Step 4: Deploy Data Product

Run the generated model SQL in Snowsight to create the `RETAIL_CUSTOMER_CHURN_RISK` table.

**Option A: Snowflake dbt Projects**
```sql
-- Import generated SQL into dbt project, then:
dbt run --select retail_customer_churn_risk
```

**Option B: Direct SQL**
```sql
-- Paste and run the generated model.sql in Snowsight
```

### Step 5: Apply Governance & Monitoring

Run these scripts in order:

```sql
-- 1. Apply masking policies
@03_deliver/02_generated_output/masking_policies.sql

-- 2. Create semantic view and marketplace listing
@03_deliver/03_semantic_view_marketplace.sql

-- 3. Setup monitoring with Data Metric Functions
@04_operate/monitoring_observability.sql
```

### ✅ Done!

You now have a fully operational data product with:
- Churn risk scores for 10K customers
- Semantic view for Cortex Analyst
- Data quality monitoring via DMFs
- PII masking policies

---

## 📋 Overview

This repository provides a **working example** of the Retail Customer Churn Risk Data Product, following a 5-stage lifecycle:

| Stage | What | Outcome |
|-------|------|---------|
| **Discover** | Identify business need | Data Product Canvas |
| **Design** | Define contract & schema | Machine-readable Data Contract |
| **Deliver** | Build & transform | dbt models, quality tests, masking |
| **Operate** | Monitor & govern | SLA checks, alerts, usage telemetry |
| **Refine** | Evolve & iterate | Versioning, new features |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA PRODUCT LIFECYCLE                            │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌──────────┐    ┌──────────┐    ┌──────────────────────────────────────────┐
  │ DISCOVER │───▶│  DESIGN  │───▶│                DELIVER                   │
  │          │    │          │    │                                          │
  │  Canvas  │    │ Contract │    │  ┌─────────────────────────────────────┐ │
  │  (YAML)  │    │  (YAML)  │    │  │   Streamlit App (Cortex LLM)        │ │
  └──────────┘    └────┬─────┘    │  │   ┌───────────────────────────────┐ │ │
                       │          │  │   │  Input: Data Contract (YAML) │ │ │
                       │          │  │   └───────────────┬───────────────┘ │ │
                       │          │  │                   ▼                 │ │
                       ▼          │  │   ┌───────────────────────────────┐ │ │
            ┌──────────────────┐  │  │   │ Output: dbt model, schema,    │ │ │
            │ Source Tables    │  │  │   │         masking policies      │ │ │
            │ ─────────────────│  │  │   └───────────────────────────────┘ │ │
            │ • CUSTOMERS      │  │  └─────────────────────────────────────┘ │
            │ • ACCOUNTS       │──┼──────────────────────────────────────────┘
            │ • TRANSACTIONS   │  │
            │ • DIGITAL_ENGAGE │  │    ┌─────────────────────────────────────┐
            │ • COMPLAINTS     │  │    │  RETAIL_CUSTOMER_CHURN_RISK         │
            └──────────────────┘  └───▶│  ─────────────────────────────────  │
                                       │  • churn_risk_score (0-100)         │
                                       │  • risk_tier (LOW/MED/HIGH/CRIT)    │
                                       │  • primary_risk_driver              │
                                       │  • recommended_intervention         │
                                       └────────────────┬────────────────────┘
                                                        │
          ┌─────────────────────────────────────────────┴──────────────────────┐
          │                                                                    │
          ▼                                                                    ▼
  ┌──────────────┐                                                    ┌──────────────┐
  │   OPERATE    │                                                    │    REFINE    │
  │              │                                                    │              │
  │ • DMF checks │                                                    │ • Versioning │
  │ • Freshness  │                                                    │ • Evolution  │
  │ • Alerts     │                                                    │ • v2 contract│
  └──────────────┘                                                    └──────────────┘
```

---

## 📁 Repository Structure

```
data-products-code-sample/
│
├── setup.sql                          # ⭐ ONE-CLICK SETUP SCRIPT
│
├── 00_setup/                          # Individual setup scripts
│   ├── 01_deploy_streamlit_app.sql
│   ├── 02_create_sample_data.sql
│   └── README.md
│
├── 01_discover/                       # DISCOVER phase
│   └── data_product_canvas.yaml       #   Business context & stakeholders
│
├── 02_design/                         # DESIGN phase
│   └── churn_risk_data_contract.yaml  #   Schema, SLAs, quality rules
│
├── 03_deliver/                        # DELIVER phase
│   ├── 01_dbt_generator_app.py        #   Streamlit app (Cortex-powered)
│   ├── 02_generated_output/           #   Example outputs from the app
│   │   ├── retail_customer_churn_risk.sql
│   │   ├── schema.yml
│   │   ├── masking_policies.sql
│   │   └── business_rules_tests.sql
│   └── 03_semantic_view_marketplace.sql
│
├── 04_operate/                        # OPERATE phase
│   └── monitoring_observability.sql   #   DMFs, SLA, alerts, telemetry
│
├── 05_refine/                         # REFINE phase
│   ├── evolution_example.sql          #   Versioning & deployment
│   └── churn_risk_data_contract_v2.yaml  # V2 contract with new features
│
├── LICENSE
└── README.md
```

---

## 📊 The Data Product

### Retail Customer Churn Risk

A governed, daily-refreshed data product providing unified churn risk scores for retail banking customers.

**Key Features:**
- 🎯 **Churn Risk Score** (0-100) with explainable drivers
- 📊 **Risk Tiers**: LOW / MEDIUM / HIGH / CRITICAL
- 🔍 **5 Risk Signals**: Balance decline, activity reduction, low engagement, complaints, dormancy
- 💡 **Recommended Interventions**: Escalation, calls, offers, meetings

**Sample Output:**

| customer_id | risk_tier | churn_risk_score | primary_risk_driver | recommended_intervention |
|-------------|-----------|------------------|---------------------|--------------------------|
| CUST-000001 | HIGH | 72 | BALANCE_DECLINE | RETENTION_OFFER |
| CUST-000042 | CRITICAL | 85 | DORMANCY | URGENT_ESCALATION |
| CUST-000123 | LOW | 18 | NONE | NO_ACTION |

---

## 🛡️ Governance

### Data Quality (Native DMFs)
- `SNOWFLAKE.CORE.NULL_COUNT` on critical columns
- `SNOWFLAKE.CORE.DUPLICATE_COUNT` on primary key
- `SNOWFLAKE.CORE.FRESHNESS` on timestamp
- Custom DMFs for business rules

### SLA
- **Freshness**: Data updated daily by 6 AM UTC
- **Availability**: 99.5%

### Access Control
- **Authorized roles**: RETENTION_ANALYST, BRANCH_MANAGER, CUSTOMER_ANALYTICS
- **PII masking**: customer_name masked for unauthorized users

---

## 📚 Resources

- [Snowflake Data Metric Functions](https://docs.snowflake.com/en/user-guide/data-quality-intro)
- [Snowflake Semantic Views](https://docs.snowflake.com/en/user-guide/views-semantic)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)
- [Cortex LLM Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)

---

## 📄 License

MIT License - see [LICENSE](./LICENSE)

---

<p align="center">
  <i>Built with ❄️ Snowflake, 🤖 Cortex, and 🔥 dbt</i>
</p>
