# Data Products for Financial Services

Code samples demonstrating how to build **Data Products** on Snowflake, illustrated through a **Retail Customer Churn Risk** example for banking.

---

## Overview: Data Product Lifecycle

This repository follows a 5-stage lifecycle for delivering data products:

<p align="center">
  <img src="images/data-product-lifecycle.png" alt="Data Product Lifecycle" width="700"/>
</p>

| Stage | What Happens | Repo Folder |
|-------|--------------|-------------|
| **Discover** | Business event storms identify candidate data products | `01_discover/` |
| **Design** | Define specifications in a canvas, convert to a machine-readable data contract | `02_design/` |
| **Deliver** | Build data assets with code, metadata, and compute | `03_deliver/` |
| **Operate** | Monitor SLA, data quality, usage, and data drifts | `04_operate/` |
| **Refine** | Evolve with new features and versions | `05_refine/` |

---

## How to Use This Repo

**Prerequisites:** The Discover and Design phases are complete. The data product canvas is at `01_discover/data_product_canvas.yaml` and the data contract is at `02_design/churn_risk_data_contract.yaml`. Follow the steps below to complete the **Deliver**, **Operate**, and **Refine** phases.

### Step 1: Setup Environment

**Option A:** Clone repo locally and run scripts in Snowsight
```bash
git clone https://github.com/srini86/data-products-lifecycle-fsi-example
```

**Option B:** Create a Snowsight Worksheet from Git  
Snowsight → **Projects** → **Worksheets** → **Create from Git Repository**

Then open `00_setup/setup.sql` in Snowsight and run **Steps 1–4**.

### Step 2: Create Streamlit App

In Snowsight: **Projects → Streamlit → + Streamlit App**
- Name: `dbt_code_generator`  
- Database: `RETAIL_BANKING_DB`, Schema: `GOVERNANCE`
- Paste code from `03_deliver/01_dbt_generator_app.py` → Click **Run**

### Step 3: Generate Data Product Code

1. Open the Streamlit app in Snowsight
2. Choose an input method:
   - **Paste YAML:** Copy contents of `02_design/churn_risk_data_contract.yaml` and paste
   - **Load from Stage:** Enter `RETAIL_BANKING_DB.GOVERNANCE.DATA_CONTRACTS` and filename `churn_risk_data_contract.yaml`
3. Click **Generate All Outputs**
4. The app generates:
   - `retail_customer_churn_risk.sql` — dbt model with transformation logic
   - `schema.yml` — dbt schema with documentation and tests
   - `masking_policies.sql` — Snowflake masking policies

> 💡 **Sample outputs** are available at `03_deliver/02_generated_output/` for reference.

### Step 4: Deploy Data Product

1. **Deploy dbt model:**
   - Create a **dbt Project** in Snowsight → Add `retail_customer_churn_risk.sql` and `schema.yml` → **Compile** and **Run**
2. **Apply masking policies:**
   - Run `masking_policies.sql` in a Snowsight Worksheet
3. **Create Semantic View and Marketplace listing:**
   - Run `03_deliver/03_semantic_view_marketplace.sql`

### Step 5: Setup Monitoring

Run in Snowsight:
- `04_operate/monitoring_observability.sql` — Sets up Data Metric Functions (DMFs) and alerts

### Step 6: Verify the Data Product

1. **Database Explorer:** Snowsight → **Data** → **Databases** → `RETAIL_BANKING_DB` → `DATA_PRODUCTS` → `RETAIL_CUSTOMER_CHURN_RISK`
2. **Private Sharing:** Snowsight → **Data Products** → **Private Sharing** → Search for "Retail Customer Churn Risk"

### Cleanup

Run `06_cleanup/cleanup.sql` to remove all demo resources.

---

## Folder Structure

```
├── 00_setup/                       # Setup script (database, tables, sample data)
├── 01_discover/                    # Data Product Canvas
├── 02_design/                      # Data Contract (YAML)
├── 03_deliver/                     # Streamlit app + generated outputs
│   ├── 01_dbt_generator_app.py
│   ├── 02_generated_output/        # Sample generated files
│   └── 03_semantic_view_marketplace.sql
├── 04_operate/                     # Data Metric Functions & monitoring
├── 05_refine/                      # Evolution example (v2 contract)
└── 06_cleanup/                     # Cleanup script
```
