# Data Products for Financial Services

Code samples demonstrating how to build Data Products on Snowflake using the **Retail Customer Churn Risk** use case.

---

## Overview: Data Product Lifecycle

This repo follows a 5-stage lifecycle for delivering data products:

```
                            ┌──────────────┐
                            │   DISCOVER   │
                            │              │
                            │ Business     │
                            │ event storms │
                            │ → candidate  │
                            │ data products│
                            └──────┬───────┘
                                   │
        ┌──────────────┐           │           ┌──────────────┐
        │    REFINE    │           │           │    DESIGN    │
        │              │           ▼           │              │
        │ Evolve with  │◀────  ❄️  ────▶      │ Canvas →     │
        │ new features │                       │ Data Contract│
        │ and versions │                       │ (YAML)       │
        └──────────────┘                       └──────┬───────┘
                ▲                                     │
                │           ┌──────────────┐          │
                │           │   DELIVER    │          │
                └───────────│              │◀─────────┘
                            │ Code +       │
                            │ metadata +   │
                            │ compute      │
                            └──────┬───────┘
                                   │
                            ┌──────▼───────┐
                            │   OPERATE    │
                            │              │
                            │ Monitor SLA, │
                            │ usage, drift │
                            └──────────────┘
```

| Stage | What Happens | Repo Folder |
|-------|--------------|-------------|
| **Discover** | Business process event storms → candidate data products | `01_discover/` |
| **Design** | Specifications in canvas → machine-readable data contract | `02_design/` |
| **Deliver** | Build data assets with code, metadata, and compute | `03_deliver/` |
| **Operate** | Monitor SLA per contract, usage, and data drifts | `04_operate/` |
| **Refine** | Evolve with new features and versions | `05_refine/` |

---

## How to Use This Repo

### Step 1: Setup Environment

```bash
git clone https://github.com/sfc-gh-skuppusamy/data-products-code-sample
```

Open `00_setup/setup.sql` in Snowsight → Run **Steps 1-4**

### Step 2: Create Streamlit App

In Snowsight: **Projects → Streamlit → + Streamlit App**
- Name: `dbt_code_generator`  
- Database: `RETAIL_BANKING_DB`, Schema: `GOVERNANCE`
- Paste code from `03_deliver/01_dbt_generator_app.py` → Run

### Step 3: Generate Data Product

1. Open the Streamlit app
2. Select `churn_risk_data_contract.yaml` from stage
3. Click **Generate All Outputs**
4. Copy generated DBT artefacts → Create DBT projects on Snowflake -> add files to the project, Compile and Run.
5. Copy masking_policies.yml  -> Run in Snowsight

### Step 4: Apply Governance & Monitoring

Run in Snowsight:
- `03_deliver/03_semantic_view_marketplace.sql`
- `04_operate/monitoring_observability.sql`

### Step 5: Verify the new data products created
1. Snowsight Database Explorer -> <name pf data product>
2. 

### Cleanup
Run `06_cleanup/cleanup.sql` to remove all resources.

---

## Folder Structure

```
├── 00_setup/                       # Setup script
├── 01_discover/                    # Data Product Canvas
├── 02_design/                      # Data Contract (YAML)
├── 03_deliver/                     # Streamlit app + outputs
├── 04_operate/                     # DMF monitoring
├── 05_refine/                      # Evolution (v2 contract)
└── 06_cleanup/                     # Cleanup script
```

---

## License

MIT
