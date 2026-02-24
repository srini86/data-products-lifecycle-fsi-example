# Data Products for Financial Services

Build a production-ready **Retail Customer Churn Risk** data product on Snowflake — from data contract to governed, tested, deployed table.

📝 **Blog Post:** [Building Enterprise Grade Data Products for FSI — Moving from Strategy to Tactics](https://datadonutz.medium.com/building-regulatory-grade-data-products-on-snowflake-for-fsi-938895e25e35)

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

## Architecture: LLM vs Agent

This repo provides two approaches. Both start from the same data contract and produce the same table.

**Streamlit — LLM (single-pass)**

```
Contract YAML ──► Cortex LLM ──► Generated SQL
                  (one prompt)    schema.yml      ──► Manual deploy
                                  masking.sql          via Snowsight
                                  dmf_setup.sql
```

**Cortex Code — Agent (multi-skill orchestration)**

```
Contract YAML ──► Cortex Code Agent
                       │
                  ┌────┴────────────────────────┐
                  │         7 Skills             │
                  │  ┌─────────┐  ┌───────────┐ │
                  │  │model-sql│  │ schema-yml│ │     prompt.md
                  │  │  (AI)   │  │ (template)│ │    (guardrails)
                  │  └─────────┘  └───────────┘ │        │
                  │  ┌─────────┐  ┌───────────┐ │        ▼
                  │  │masking  │  │ dmf-setup │ │   Plan ► Generate
                  │  │(template│  │ (template)│ │   ► Validate ► Deploy
                  │  └─────────┘  └───────────┘ │   ► Test ► Learn
                  │  ┌─────────┐  ┌───────────┐ │        │
                  │  │test-gen │  │ deployer  │ │        ▼
                  │  │(template│  │ (snow CLI)│ │   Error Playbook
                  │  └─────────┘  └───────────┘ │  (lessons persist)
                  └─────────────────────────────┘
```

| | **Streamlit (LLM)** | **Cortex Code (Agent)** |
|---|---|---|
| **Invocations** | 1 prompt → 1 response | N skills → N artifacts, iteratively |
| **AI usage** | LLM generates SQL; templates handle rest | LLM generates SQL only; templates handle 6 of 7 |
| **Memory** | Stateless | `prompt.md` + Error Playbook persist across sessions |
| **Governance** | Implicit in app code | Explicit in `prompt.md` (forbidden patterns, naming rules) |
| **Iteration** | Re-run entire generation | Re-run individual skill |

---

## How to Use This Repo

### Step 1: Setup Environment

- Clone the repo:
  ```bash
  git clone https://github.com/srini86/data-products-lifecycle-fsi-example
  ```
- Open `00_setup/setup.sql` in Snowsight
- Run Steps 1–4 to create database, schemas, and sample data
- Run Step 5 to create the Streamlit app (only needed for 3a)
- Run Step 6 to verify all assets

### Step 2: Review the Data Contract

- Open `02_design/churn_risk_data_contract.yaml`
- This contract defines schema, quality rules, masking policies, and SLAs
- It is the **single input** that drives all code generation in Step 3

### Step 3: Generate & Deploy Data Product

Choose **3a** or **3b**:

#### Step 3a: Streamlit App

- Open Snowsight → Projects → Streamlit → `dbt_code_generator`
- Paste the contract YAML or load from stage
- Click **Generate All Outputs** — produces:
  - `retail_customer_churn_risk.sql` (dbt model)
  - `schema.yml` (tests + docs)
  - `masking_policies.sql`
- Create a dbt Project in Snowsight → add model + schema → Compile → Run
- Run `masking_policies.sql` in a worksheet
- Run `03_deliver/generated_output_samples/02_data_quality_dmf.sql` for DMF setup
- Run `03_deliver/generated_output_samples/03_semantic_view_marketplace.sql` for semantic view
- Sample outputs: `03_deliver/generated_output_samples/`

#### Step 3b: Cortex Code

- Start Cortex Code in the repo directory — skills auto-load from `.cortex/skills/`
- Use these prompts to walk through the lifecycle:
  1. `"Read the data contract at 02_design/churn_risk_data_contract.yaml and generate a complete dbt project — model SQL, schema.yml, and tests"`
  2. `"Generate masking policies and DMF setup SQL based on the governance rules in the contract"`
  3. `"Deploy the dbt project to Snowflake using snow dbt deploy and run it"`
  4. `"Validate the deployment — run tests, check row counts, verify masking is applied"`
- Full guide: [`.cortex/guides/PROMPT_INSTRUCTION_GUIDE.md`](.cortex/guides/PROMPT_INSTRUCTION_GUIDE.md) — covers skills architecture, guardrails, and error playbook

### Step 4: Operate & Monitor

- Run `04_operate/monitoring_observability.sql` in Snowsight
  - Freshness SLAs and availability
  - Quality expectation status and masking verification
  - Usage by role/user and query patterns

### Step 5: Refine & Evolve

- See `05_refine/churn_risk_data_contract_v2.yaml` for an evolved contract (adds CLV, vulnerability indicator)
- Run `05_refine/evolution_example.sql` for schema evolution patterns

### Cleanup

- Run `06_cleanup/cleanup.sql` to remove all demo resources

---

## Folder Structure

```
.cortex/
  ├── skills/capture-feedback/         # CoCo feedback skill
  └── guides/                          # CoCo guides & prompts
        ├── PROMPT_INSTRUCTION_GUIDE.md
        └── TODO.md
00_setup/                              # Setup script + lifecycle diagram
01_discover/                           # Data product canvas
02_design/                             # Data contract + diagrams
03_deliver/
  ├── 01_code_generator_service.py     # Code generator service
  ├── validate_deployment.sql          # Validation tests
  └── generated_output_samples/        # CoCo-generated sample outputs
        ├── dbt_project/               # Complete dbt project
        ├── masking_policies.sql
        ├── dmf_setup.sql
        ├── 02_data_quality_dmf.sql
        └── 03_semantic_view_marketplace.sql
04_operate/                            # Monitoring & RACI template
05_refine/                             # Contract v2 + evolution examples
06_cleanup/                            # Cleanup script
```

---

> **Disclaimer:** This is a personal project for educational and demonstration purposes.
