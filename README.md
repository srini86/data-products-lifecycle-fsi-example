# Data Products for Financial Services

Build a production-ready **Retail Customer Churn Risk** data product on Snowflake — from data contract to governed, tested, deployed table.

📝 **Blog Post:** [Building Enterprise Grade Data Products for FSI — Moving from Strategy to Tactics](https://datadonutz.medium.com/building-regulatory-grade-data-products-on-snowflake-for-fsi-938895e25e35)

<p align="center">
  <img src="coco-demo.gif" alt="Cortex Code lifecycle demo" width="700"/>
</p>

---

## Quick Start

Two steps to go from zero to a governed, deployed data product:

1. **SETUP** — run `00_setup/setup.sql` in Snowsight to create the database, schemas, and sample data
2. **START DPLC** (Data Product Lifecycle) — open Cortex Code in this directory and type `$dplc-accelerator`

CoCo takes it from there — Discover → Design → Deliver → Operate → Refine, guided step by step.

<p align="center">
  <img src="assets/lifecycle-tracker.png" alt="Lifecycle tracker" width="600"/>
</p>

---

## Data Product Lifecycle

<p align="center">
  <img src="00_setup/data-product-lifecycle.png" alt="Data Product Lifecycle" width="700"/>
</p>

| Stage | What Happens | Folder |
|-------|-------------|--------|
| **Discover** | Event storms identify candidate data products | `01_discover/` |
| **Design** | Canvas → machine-readable data contract | `02_design/` |
| **Deliver** | Generate code, deploy, test | `03_deliver/` |
| **Operate** | Monitor SLAs, quality, usage | `04_operate/` |
| **Refine** | Evolve with new features and versions | `05_refine/` |

---

## How to Use This Repo

### The `_example/` Convention

Every phase folder contains an `_example/` sub-folder with **ready-made reference artifacts** — data contracts, dbt projects, masking policies, monitoring SQL, and more. When you clone the repo they are immediately available.

You have two paths through each phase:

| Path | How | When to use |
|------|-----|-------------|
| **Use the example** | Copy from `_example/` and adapt | Fastest way to explore end-to-end |
| **Generate your own** | Run CoCo prompts from `$dplc-accelerator` | Building a real data product |

The **lifecycle tracker advances only when you have placed your own artifact at the expected path outside `_example/`** — so `_example/` files serve as reference, never as completion signals.

---

### Step 1: SETUP

- Clone the repo:
  ```bash
  git clone https://github.com/srini86/data-products-lifecycle-fsi-example
  cd data-products-lifecycle-fsi-example
  ```
- Open `00_setup/setup.sql` in Snowsight and run Steps 1–4 to create the database, schemas, warehouse, and load sample data
- Run Step 5 to verify all source tables are present

### Step 2: START DPLC (Data Product Lifecycle)

Start Cortex Code in the repo directory:

```bash
cortex
```

Then type:

```
$dplc-accelerator
```

The skill detects where you are in the lifecycle, displays a tracker, and guides you through each phase with ready-to-run prompts:

| Phase | What to expect |
|-------|----------------|
| **Discover** | Canvas walkthrough — requirements confirmed, ambiguities flagged before you write a line of code |
| **Design** | ODCS v2.2 contract YAML generated and verified against your actual Snowflake source tables |
| **Deliver** | dbt model SQL, schema tests, masking policies, DMF quality checks — deployed and validated end-to-end |
| **Operate** | Freshness SLA status, quality gate PASS/FAIL per rule, and top consumers by role — live monitoring confirmed |
| **Refine** | v1→v2 contract diff, schema evolution SQL, regenerated artifacts — quality gates re-run and passing |

Use the default prompts (type a step number) or describe your own goal (e.g. `Deliver: create dbt model`).

### Cleanup

- Run `06_cleanup/cleanup.sql` in Snowsight to remove all demo resources

---

## Folder Structure

```
.cortex/
  └── skills/
        ├── dplc-accelerator/        # Lifecycle tracker skill — start here
        ├── contract-generator/      # Generate ODCS v2.2 contracts
        ├── contract-verifier/       # Verify contract against Snowflake tables
        └── data-product-generator/ # Generate dbt model, tests, governance SQL
00_setup/                              # Setup script + lifecycle diagram
01_discover/                           # Data product canvas
02_design/
  ├── README.md                        # Phase guide
  ├── data_contract_informs.png        # Contract-driven architecture diagram
  └── _example/
        └── churn_risk_data_contract.yaml  # FSI churn-risk reference contract
03_deliver/
  ├── _example/
  │   ├── dbt_project/               # Reference dbt project (model, schema, tests)
  │   ├── masking_policies.sql       # Reference masking policy DDL
  │   └── dmf_setup.sql              # Reference DMF quality checks DDL
  ├── code_generation_flow.png
  └── cortex_code_skills_flow.png
04_operate/
  ├── README.md                        # Phase guide
  ├── raci_template.md                 # Reusable RACI template
  └── _example/
        └── monitoring_observability.sql
05_refine/
  ├── README.md                        # Phase guide
  └── _example/
        ├── churn_risk_data_contract_v2.yaml
        └── evolution_example.sql
06_cleanup/                            # Cleanup script
prompt.md                              # CoCo standing rules (auto-read at session start)
```

---

> **Disclaimer:** This is a personal project for educational and demonstration purposes.
