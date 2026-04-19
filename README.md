# Data Products for Financial Services

Build a production-ready **Retail Customer Churn Risk** data product on Snowflake — from data contract to governed, tested, deployed table.

📝 **Blog Post:** [Building Enterprise Grade Data Products for FSI — Moving from Strategy to Tactics](https://datadonutz.medium.com/building-regulatory-grade-data-products-on-snowflake-for-fsi-938895e25e35)

---

## Quick Start

Open Cortex Code (CoCo) in this directory and type:

```
$dplc-accelerator
```

The skill launches a lifecycle tracker and guides you through every phase — Discover → Design → Deliver → Operate → Refine — with ready-to-run CoCo prompts at each step.

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

### Step 1: Setup Environment

- Clone the repo:
  ```bash
  git clone https://github.com/srini86/data-products-lifecycle-fsi-example
  ```
- Open `00_setup/setup.sql` in Snowsight
- Run Steps 1–4 to create database, schemas, and sample data
- Run Step 5 to verify all assets

### Step 2: Design Your Data Contract

- An example contract is provided at `02_design/_example/churn_risk_data_contract.yaml` — use it as a reference
- To create your own, provide CoCo with your Data Product Canvas (or requirements) and ask it to generate a contract:
  ```
  "Generate an ODCS v2.2 data contract for <your data product>. 
   Use 02_design/_example/churn_risk_data_contract.yaml as a reference for structure."
  ```
- The contract defines schema, quality rules, masking policies, and SLAs
- It is the **single input** that drives all code generation in Step 3

### Step 3: Deliver with Cortex Code

Start Cortex Code in the repo directory — the `$dplc-accelerator` skill guides you through each prompt interactively:

```bash
cortex
```

Then type `$dplc-accelerator` to launch the lifecycle tracker. The skill presents these five prompts in sequence:

1. `"Read the data contract at 02_design/retail_customer_churn_risk_contract.yaml and generate a complete dbt project — model SQL, schema.yml, and tests"`
2. `"Generate masking policies and DMF setup SQL based on the governance rules in the contract"`
3. `"Generate monitoring and observability SQL — freshness SLAs, quality checks, usage tracking, and alerts"`
4. `"Deploy the dbt project to Snowflake using snow dbt deploy and run it"`
5. `"Validate the deployment — run tests, check row counts, verify masking is applied"`

Full playbook: [`.cortex/guides/DATA_PRODUCT_PLAYBOOK.md`](.cortex/guides/DATA_PRODUCT_PLAYBOOK.md) — covers skills architecture, guardrails, and error playbook.

### Step 4: Operate & Monitor

- Monitoring SQL was generated in Prompt 3 above and deployed as part of Prompt 4
- Run `04_operate/_example/monitoring_observability.sql` in Snowsight to review or re-run independently
- What it covers:
  - Freshness SLAs and availability
  - Quality expectation status and masking verification
  - Usage by role/user and query patterns

### Step 5: Refine & Evolve

- See `05_refine/_example/churn_risk_data_contract_v2.yaml` for an evolved contract (adds CLV, vulnerability indicator)
- Run `05_refine/_example/evolution_example.sql` for schema evolution patterns

### Cleanup

- Run `06_cleanup/cleanup.sql` to remove all demo resources

---

## Folder Structure

```
.cortex/
  ├── skills/
  │     └── dplc-accelerator/        # Lifecycle tracker skill — start here
  └── guides/                        # CoCo guides & prompts
        ├── DATA_PRODUCT_PLAYBOOK.md
        └── TODO.md
00_setup/                              # Setup script + lifecycle diagram
01_discover/                           # Data product canvas
02_design/
  ├── README.md                        # Phase guide
  ├── data_contract_informs.png        # Contract-driven architecture diagram
  └── retail_customer_churn_risk_contract.yaml  # FSI churn-risk example contract
03_deliver/
  ├── dbt_project/                     # Complete dbt project (model, schema, tests)
  ├── masking_policies.sql             # PII masking policy DDL
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
