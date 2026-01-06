# 🏦 Data Products for Financial Services

> A complete code sample demonstrating how to build, deliver, and operate Data Products for FSI using Snowflake.

[![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?logo=snowflake&logoColor=white)](https://snowflake.com)
[![dbt](https://img.shields.io/badge/dbt-FF694B?logo=dbt&logoColor=white)](https://getdbt.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

---

## 📋 Overview

This repository provides a **working example** of the Retail Customer Churn Risk Data Product, following a 5-stage lifecycle:

| Stage | What | Outcome |
|-------|------|---------|
| **Discover** | Identify business need | Data Product Canvas |
| **Design** | Define contract & schema | Machine-readable Data Contract |
| **Deliver** | Build & transform | dbt models, quality tests, masking |
| **Operate** | Monitor & govern | SLA checks, alerts, usage telemetry |
| **Refine** | Evolve & iterate | Versioning, deprecation, new products |

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
  │ • SLA checks │                                                    │ • Versioning │
  │ • DQ monitor │                                                    │ • Evolution  │
  │ • Alerts     │                                                    │ • Retirement │
  └──────────────┘                                                    └──────────────┘
```

---

## 📁 Repository Structure

```
data-products-lifecycle-fsi-example/
│
├── 00_setup/                          # Snowflake setup
│   ├── 01_deploy_streamlit_app.sql    #   Create DB, stages, deploy app
│   ├── 02_create_sample_data.sql      #   Generate sample data
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
│   └── 03_semantic_view_marketplace.sql  # Publish to Internal Marketplace
│
├── 04_operate/                        # OPERATE phase
│   └── monitoring_observability.sql   #   SLA, DQ, alerts, telemetry
│
├── 05_refine/                         # REFINE phase
│   └── evolution_example.sql          #   Versioning & deprecation
│
├── LICENSE
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites

- Snowflake account with `ACCOUNTADMIN` role
- Snowsight (Snowflake web UI)

### Step 1: Setup Infrastructure

```sql
-- Run in Snowsight: 00_setup/01_deploy_streamlit_app.sql (Steps 1-2)
-- Creates: RETAIL_BANKING_DB, schemas, stages
```

### Step 2: Upload Files

Upload to Snowflake stages via Snowsight:

| File | Stage |
|------|-------|
| `02_design/churn_risk_data_contract.yaml` | `@GOVERNANCE.data_contracts` |
| `03_deliver/01_dbt_generator_app.py` | `@GOVERNANCE.streamlit_apps` |

### Step 3: Create Sample Data

```sql
-- Run in Snowsight: 00_setup/02_create_sample_data.sql
-- Creates: 10K customers, 25K accounts, 2M transactions
```

### Step 4: Deploy Streamlit App

```sql
-- Run in Snowsight: 00_setup/01_deploy_streamlit_app.sql (Steps 5-6)
-- Creates: dbt_code_generator Streamlit app
```

### Step 5: Generate dbt Code

1. Open the Streamlit app
2. Paste the data contract YAML
3. Click **Generate All Outputs**
4. Download: `model.sql`, `schema.yml`, `masking_policies.sql`

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
|------------|-----------|------------------|---------------------|--------------------------|
| C-00001 | HIGH | 72 | BALANCE_DECLINE | RETENTION_OFFER |
| C-00042 | CRITICAL | 85 | DORMANCY | URGENT_ESCALATION |
| C-00123 | LOW | 18 | NONE | NO_ACTION |

---

## 🛡️ Governance

### Data Quality Rules
- **Completeness**: No nulls in required fields
- **Uniqueness**: customer_id is unique
- **Validity**: risk_tier ∈ {LOW, MEDIUM, HIGH, CRITICAL}
- **Business Rules**: 
  - `churn_risk_score` between 0-100
  - `risk_tier` derived correctly from score

### SLA
- **Freshness**: Data updated daily by 6 AM UTC
- **Availability**: 99.5%

### Access Control
- **Authorized roles**: RETENTION_ANALYST, BRANCH_MANAGER, CUSTOMER_ANALYTICS
- **PII masking**: customer_name masked for unauthorized users

---

## 📚 Resources

- [Snowflake dbt Projects](https://docs.snowflake.com/en/user-guide/ui-snowsight-dbt)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)
- [Cortex LLM Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Snowflake Semantic Views](https://docs.snowflake.com/en/user-guide/ui-snowsight-semantic-views)

---

## 📄 License

MIT License - see [LICENSE](./LICENSE)

---

<p align="center">
  <i>Built with ❄️ Snowflake, 🤖 Cortex, and 🔥 dbt</i>
</p>
