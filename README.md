# 🏦 Data Products for Financial Services on Snowflake

[![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=flat&logo=snowflake&logoColor=white)](https://snowflake.com)
[![dbt](https://img.shields.io/badge/dbt-FF694B?style=flat&logo=dbt&logoColor=white)](https://getdbt.com)
[![Streamlit](https://img.shields.io/badge/Streamlit-FF4B4B?style=flat&logo=streamlit&logoColor=white)](https://streamlit.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **Production-ready code samples for building regulatory-grade data products in Financial Services**

This repository accompanies the blog post *"Building Regulatory-Grade Data Products on Snowflake for FSI"* and demonstrates a complete 5-stage lifecycle for delivering governed, contract-driven data products.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Quick Start](#-quick-start)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Repository Structure](#-repository-structure)
- [The 5-Stage Lifecycle](#-the-5-stage-lifecycle)
- [Example: Retail Customer Churn Risk](#-example-retail-customer-churn-risk)
- [Contract-Driven Code Generation](#-contract-driven-code-generation)
- [Testing & Validation](#-testing--validation)
- [Monitoring & Observability](#-monitoring--observability)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

This repository provides a **complete, working example** of delivering a data product in Financial Services, following best practices for:

- ✅ **Governance** - Data contracts, masking policies, access controls
- ✅ **Quality** - Automated testing, business rule validation
- ✅ **Observability** - SLA monitoring, freshness checks, usage telemetry
- ✅ **Discoverability** - Semantic views, internal marketplace listings
- ✅ **AI-Assisted Development** - Cortex LLM generates code from English specs

### Key Innovation: Contract-Driven Development

Instead of writing SQL manually, define your data product in a **YAML contract** with English descriptions. The included Streamlit app uses **Snowflake Cortex** to generate production-ready code:

```yaml
# Define in English...
churn_risk_score:
  derivation: |
    Calculate risk score using weighted factors:
    - declining_balance_flag: +20 points
    - reduced_activity_flag: +20 points
    Cap final score between 0 and 100
```

```sql
-- AI generates SQL...
LEAST(100, GREATEST(0,
    20 + -- base score
    IFF(declining_balance_flag, 20, 0) +
    IFF(reduced_activity_flag, 20, 0) + ...
)) AS churn_risk_score
```

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/data-products-fsi.git
cd data-products-fsi

# Run the setup script (interactive)
./setup.sh

# Or run individual steps manually - see Installation section
```

---

## 📌 Prerequisites

| Requirement | Details |
|-------------|---------|
| **Snowflake Account** | Trial or paid account with ACCOUNTADMIN access |
| **Snowflake Warehouse** | COMPUTE_WH or equivalent (XSMALL is sufficient) |
| **Cortex Access** | For AI-powered code generation (optional) |
| **dbt** | Either Snowflake dbt Projects or dbt Core 1.5+ |
| **Git** | For cloning the repository |

### Optional Tools
- **SnowSQL CLI** - For running setup scripts
- **Python 3.9+** - For local testing of Streamlit app

---

## 📥 Installation

### Option 1: Automated Setup (Recommended)

```bash
# Make the setup script executable
chmod +x setup.sh

# Run interactive setup
./setup.sh
```

The script will guide you through:
1. Creating the database and schemas
2. Generating sample data
3. Deploying the dbt model
4. Setting up monitoring
5. (Optional) Deploying the Streamlit app

### Option 2: Manual Setup

#### Step 1: Create Sample Data
```sql
-- Run in Snowflake (Snowsight or SnowSQL)
-- Execute: 03_deliver/03a_create_sample_data.sql

-- This creates:
-- • RETAIL_BANKING_DB database
-- • RAW schema with 5 source tables
-- • ~1,000 customers, ~2,500 accounts, ~50,000 transactions
```

#### Step 2: Deploy the dbt Model

**Using Snowflake dbt Projects:**
1. Create a new dbt project in Snowflake
2. Upload files from `03_deliver/03c_output_examples/`
3. Run: `dbt run --select retail_customer_churn_risk`

**Using dbt Core:**
```bash
# Copy model files to your dbt project
cp 03_deliver/03c_output_examples/retail_customer_churn_risk.sql models/
cp 03_deliver/03c_output_examples/schema.yml models/

# Run dbt
dbt run --select retail_customer_churn_risk
dbt test --select retail_customer_churn_risk
```

#### Step 3: Apply Masking Policies
```sql
-- Execute: 03_deliver/03c_output_examples/masking_policies.sql
```

#### Step 4: Create Semantic View
```sql
-- Execute: 03_deliver/03d_semantic_view_marketplace.sql
```

#### Step 5: Set Up Monitoring
```sql
-- Execute: 04_operate/monitoring_observability.sql
```

---

## 📁 Repository Structure

```
data-products-fsi/
│
├── 01_discover/
│   └── data_product_canvas.yaml          # Business discovery canvas
│
├── 02_design/
│   └── churn_risk_data_contract.yaml     # Machine-readable data contract
│
├── 03_deliver/
│   ├── 03a_create_sample_data.sql        # Sample data generation
│   ├── 03b_dbt_generator_app.py          # Streamlit code generator
│   ├── 03c_output_examples/              # Generated code examples
│   │   ├── retail_customer_churn_risk.sql
│   │   ├── schema.yml
│   │   ├── masking_policies.sql
│   │   └── business_rules_tests.sql
│   └── 03d_semantic_view_marketplace.sql
│
├── 04_operate/
│   └── monitoring_observability.sql      # Monitoring & alerts
│
├── 05_refine/
│   └── evolution_example.sql             # Product evolution patterns
│
├── setup.sh                              # Automated setup script
└── README.md
```

---

## 🔄 The 5-Stage Lifecycle

| Stage | Purpose | Deliverable | File |
|-------|---------|-------------|------|
| **1. Discover** | Identify business need, stakeholders | Data Product Canvas | `01_discover/data_product_canvas.yaml` |
| **2. Design** | Codify requirements as contract | Data Contract | `02_design/churn_risk_data_contract.yaml` |
| **3. Deliver** | Build transformation & serving | dbt Model + Semantic View | `03_deliver/` |
| **4. Operate** | Monitor quality & adoption | Alerts & Dashboards | `04_operate/monitoring_observability.sql` |
| **5. Refine** | Evolve based on feedback | Version Updates | `05_refine/evolution_example.sql` |

---

## 📊 Example: Retail Customer Churn Risk

### Business Context
A retail bank needs to identify customers at risk of churning to enable:
- 🎯 Targeted retention campaigns
- 📞 Branch manager interventions
- 📈 Executive KPI reporting

### Data Product Outputs

| Column | Type | Description |
|--------|------|-------------|
| `customer_id` | STRING | Unique customer identifier |
| `churn_risk_score` | INT | Risk score 0-100 (higher = more risk) |
| `risk_tier` | STRING | LOW, MEDIUM, HIGH, CRITICAL |
| `primary_risk_driver` | STRING | Main contributing factor |
| `recommended_intervention` | STRING | Suggested action |

### Risk Factors

The model evaluates 5 behavioral signals:

| Factor | Weight | Trigger |
|--------|--------|---------|
| 💰 Declining Balance | +20 | Balance < £500 or primary < £100 |
| 📉 Reduced Activity | +20 | Transaction count down >30% |
| 📱 Low Engagement | +15 | < 3 logins, no mobile app usage |
| 😤 Complaints | +15 | Open complaints or ≥2 in 12 months |
| 💤 Dormancy | +25 | No transactions for >45 days |

### Sample Query

```sql
-- Find high-risk customers needing intervention
SELECT 
    customer_id,
    customer_name,
    churn_risk_score,
    risk_tier,
    primary_risk_driver,
    recommended_intervention
FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK
WHERE risk_tier IN ('HIGH', 'CRITICAL')
ORDER BY churn_risk_score DESC
LIMIT 50;
```

---

## 🤖 Contract-Driven Code Generation

### How It Works

```
┌─────────────────────────────┐
│  Data Contract (YAML)       │
│  - Schema with derivations  │
│  - Masking policies         │
│  - Business rules           │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Streamlit App              │
│  (03b_dbt_generator_app.py) │
│  + Snowflake Cortex LLM     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Generated Outputs          │
│  - model.sql (dbt)          │
│  - schema.yml               │
│  - masking_policies.sql     │
└─────────────────────────────┘
```

### Deploy the Streamlit App

```sql
-- Create stage and upload app
CREATE STAGE IF NOT EXISTS RETAIL_BANKING_DB.RAW.APP_STAGE;
PUT file://03_deliver/03b_dbt_generator_app.py @RETAIL_BANKING_DB.RAW.APP_STAGE;

-- Create Streamlit app
CREATE STREAMLIT RETAIL_BANKING_DB.RAW.DBT_CODE_GENERATOR
  ROOT_LOCATION = '@RETAIL_BANKING_DB.RAW.APP_STAGE'
  MAIN_FILE = '03b_dbt_generator_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH;
```

### Contract Features

The data contract (`02_design/churn_risk_data_contract.yaml`) includes:

- **English Derivations**: Natural language descriptions of column logic
- **Masking Policies**: Role-based data protection rules
- **Business Rules**: Validation constraints in plain English
- **SLA Definitions**: Freshness and availability targets

---

## ✅ Testing & Validation

### Run Business Rules Tests

```sql
-- Execute: 03_deliver/03c_output_examples/business_rules_tests.sql

-- Tests:
-- BR001: Risk tier aligns with score
-- BR002: HIGH/CRITICAL risk has driver flags
-- BR003: URGENT_ESCALATION only for CRITICAL
-- BR004: Priority matches score
```

### Run dbt Tests

```bash
dbt test --select retail_customer_churn_risk
```

### Validate Generator Output

1. Deploy the Streamlit app
2. Upload `02_design/churn_risk_data_contract.yaml`
3. Click "Generate All Outputs"
4. Compare with files in `03_deliver/03c_output_examples/`

---

## 📈 Monitoring & Observability

### Data Quality Checks

| Check | Threshold | Alert |
|-------|-----------|-------|
| Row Count | ≥ 500 | Below threshold |
| Uniqueness | 100% | Duplicates found |
| Completeness | 0 nulls | Null risk scores |
| Score Range | 0-100 | Out of bounds |
| Business Rules | 0 violations | Rule failures |

### SLA Targets

| SLA | Target |
|-----|--------|
| Data Freshness | Updated by 6 AM UTC daily |
| Availability | 99.5% |
| Query Response | < 5 seconds |

### View Health Status

```sql
-- Health summary
SELECT * FROM MONITORING.data_product_health_summary;

-- Recent DQ checks
SELECT * FROM MONITORING.data_quality_log 
ORDER BY check_timestamp DESC LIMIT 20;

-- Freshness status
SELECT * FROM MONITORING.data_freshness_status;
```

---

## 🔧 Configuration

### Environment Variables

If using SnowSQL, set these in your environment:

```bash
export SNOWFLAKE_ACCOUNT="your-account"
export SNOWFLAKE_USER="your-username"
export SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
export SNOWFLAKE_DATABASE="RETAIL_BANKING_DB"
```

### Customization

| Setting | Location | Default |
|---------|----------|---------|
| Database name | All SQL files | `RETAIL_BANKING_DB` |
| Warehouse | All SQL files | `COMPUTE_WH` |
| Sample data size | `03a_create_sample_data.sql` | ~1,000 customers |
| Cortex model | `03b_dbt_generator_app.py` | `claude-3-5-sonnet` |

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📚 Resources

- [Snowflake Semantic Views](https://docs.snowflake.com/en/user-guide/views-semantic/overview)
- [Snowflake Internal Marketplace](https://docs.snowflake.com/en/user-guide/collaboration/listings/organizational)
- [Snowflake Cortex LLM Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [dbt Documentation](https://docs.getdbt.com/)
- [Data Contract Specification](https://datacontract.com/)

---

## 💬 Support

- 📧 Email: retail-data-support@bank.com
- 💬 Slack: #retail-analytics
- 📝 Issues: [GitHub Issues](https://github.com/YOUR_USERNAME/data-products-fsi/issues)

---

<p align="center">
  Made with ❄️ for the Financial Services community
</p>
