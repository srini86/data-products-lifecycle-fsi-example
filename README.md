# Data Products for Financial Services

Code samples for building Data Products on Snowflake, demonstrating the **Retail Customer Churn Risk** use case.

---

## Quick Start

### 1. Clone & Setup

```bash
git clone https://github.com/sfc-gh-skuppusamy/data-products-code-sample
cd data-products-code-sample
```

Open `00_setup/setup.sql` in Snowsight and run **Steps 1-4** (creates DB, tables, sample data, stages).

### 2. Create Streamlit App

Go to **Snowsight → Projects → Streamlit → + Streamlit App**
- Name: `dbt_code_generator`
- Database: `RETAIL_BANKING_DB`, Schema: `GOVERNANCE`
- Copy code from `03_deliver/01_dbt_generator_app.py` → Paste → Run

### 3. Generate & Deploy

1. In the Streamlit app, select `churn_risk_data_contract.yaml` from stage
2. Click **Generate All Outputs**
3. Copy the generated SQL and run in Snowsight

### 4. Apply Governance

Run these scripts in Snowsight:
- `03_deliver/03_semantic_view_marketplace.sql`
- `04_operate/monitoring_observability.sql`

### Cleanup

```sql
-- Run 06_cleanup/cleanup.sql to remove all resources
```

---

## Folder Structure

```
├── 00_setup/setup.sql              # Setup script
├── 01_discover/                    # Data Product Canvas
├── 02_design/                      # Data Contract (YAML)
├── 03_deliver/                     # Streamlit app + generated outputs
├── 04_operate/                     # Monitoring with DMFs
├── 05_refine/                      # Evolution example (v2 contract)
└── 06_cleanup/                     # Cleanup script
```

---

## Data Product Lifecycle

| Stage | Output |
|-------|--------|
| Discover | Business canvas |
| Design | Data contract |
| Deliver | dbt model, masking policies |
| Operate | DMF monitoring, alerts |
| Refine | Versioning, new features |

---

## License

MIT
