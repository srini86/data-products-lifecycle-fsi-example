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

### Step 1: Setup Environment

**Option A:** Clone repo locally and run scripts in Snowsight
```bash
git clone https://github.com/sfc-gh-skuppusamy/data-products-code-sample
```

**Option B:** Create a Snowsight Worksheet from Git  
Snowsight → **Projects** → **Worksheets** → **Create from Git Repository**

Then open `00_setup/setup.sql` in Snowsight and run **Steps 1–4**.

### Step 2: Create Streamlit App

In Snowsight: **Projects → Streamlit → + Streamlit App**
- Name: `dbt_code_generator`  
- Database: `RETAIL_BANKING_DB`, Schema: `GOVERNANCE`
- Paste code from `03_deliver/01_dbt_generator_app.py` → Click **Run**

### Step 3: Generate Data Product

1. Open the Streamlit app in Snowsight
2. Select `churn_risk_data_contract.yaml` from the stage dropdown
3. Click **Generate All Outputs**
4. Copy the generated dbt artifacts → Create a **dbt Project** in Snowsight → Add the files → **Compile** and **Run**
5. Copy `masking_policies.sql` → Run in a Snowsight Worksheet

### Step 4: Apply Governance & Monitoring

Run the following scripts in Snowsight:
- `03_deliver/03_semantic_view_marketplace.sql` — Creates Semantic View and Marketplace listing
- `04_operate/monitoring_observability.sql` — Sets up Data Metric Functions and alerts

### Step 5: Verify the Data Product

1. **Database Explorer:** Snowsight → **Data** → **Databases** → `RETAIL_BANKING_DB` → `DATA_PRODUCTS` → `RETAIL_CUSTOMER_CHURN_RISK`
2. **Internal Marketplace:** Snowsight → **Data Products** → **Private Sharing** → Search for "Retail Customer Churn Risk"

### Cleanup

Run `06_cleanup/cleanup.sql` to remove all demo resources.

---

## Folder Structure

```
├── 00_setup/                       # Setup script (database, tables, sample data)
├── 01_discover/                    # Data Product Canvas
├── 02_design/                      # Data Contract (YAML)
├── 03_deliver/                     # Streamlit app + generated outputs
├── 04_operate/                     # Data Metric Functions & monitoring
├── 05_refine/                      # Evolution example (v2 contract)
└── 06_cleanup/                     # Cleanup script
```
