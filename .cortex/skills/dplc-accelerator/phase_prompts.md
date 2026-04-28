# DPLC Phase Prompts

Reference file for dplc-accelerator. Loaded on demand when user selects a step.

---

## Phase 0: Setup

No CoCo prompts needed. Open `00_setup/setup.sql` in Snowsight and run Steps 1–4.
Verify with Step 5 (row count check). Return here when setup is complete.

**Advance when**: All five source tables exist in `RETAIL_BANKING_DB.RAW`.

---

## Phase 1: Discover

Discover is pre-assumed — the Data Product Canvas is already in hand.

**Step 1 — Review the canvas:**

```
#01_discover/data_product_canvas.png
Summarise this Data Product Canvas:
1. What data product are we building and what business goal does it serve?
2. Who are the consumers and what decisions does this data support?
3. What source systems and tables do we need?
4. What quality and governance commitments are required (SLAs, PII, regulatory)?
5. Are there any ambiguities to resolve before designing the contract?
```

**Advance when**: Canvas is understood and requirements are confirmed.

---

## Phase 2: Design

A data contract (ODCS v2.2 YAML) is the single source of truth — every artifact in Phase 3 is derived from it.

**Step 1 — Review the example contract:**

```
#02_design/_example/churn_risk_data_contract.yaml
Summarise this data contract:
- Schema (column count, key output fields, PII fields)
- Quality rules (completeness, range, freshness SLA)
- Governance (masking policies, regulatory tags)
- Upstream source tables
Confirm all upstream tables exist in Snowflake before we proceed to Deliver.
```

> **Before advancing:** Copy `02_design/_example/churn_risk_data_contract.yaml` to `02_design/<product_name>_contract.yaml` and adapt it, OR generate your own via Step 2 or 3.

**Step 2 — (Optional) Generate contract from canvas:**

```
$contract-generator
#01_discover/data_product_canvas.png
Generate an ODCS v2.2 data contract from this canvas.
Use 02_design/_example/churn_risk_data_contract.yaml as the structure reference.
Save to 02_design/<product_name>_contract.yaml
```

**Step 3 — (Optional) Generate contract from AVRO enterprise data model:**

```
$contract-generator
#01_discover/enterprise_data_model.avsc
Generate an ODCS v2.2 data contract from this AVRO enterprise data model.
Map each record type to an upstream source table.
Map PII-annotated fields to masking policy entries.
Save to 02_design/<product_name>_contract.yaml
```

> **Review checkpoint:** Confirm all upstream tables are verified against Snowflake. Confirm all PII columns are flagged and quality rules are testable.

**Advance when**: Contract reviewed (or generated), upstream tables verified, ready for code generation.

---

## Phase 3: Deliver

Five sequential prompts. Each builds on the previous. Run them in order and review before continuing.

**Step 1 — Generate the dbt project:**

```
#02_design/<product_name>_contract.yaml
Read this data contract and generate a complete dbt project:
1. If 03_deliver/dbt_project/dbt_project.yml does not exist, copy
   03_deliver/_example/dbt_project/dbt_project.yml and profiles.yml
   into 03_deliver/dbt_project/ as the project scaffold.
2. Generate the dbt model SQL and schema.yml from the contract.
   Save to 03_deliver/dbt_project/models/
3. Generate test files matching the contract's quality rules.
   Save to 03_deliver/dbt_project/tests/
Note: use one ALTER TABLE ... ADD COLUMN statement per column
(Snowflake does not support comma-separated ADD COLUMN IF NOT EXISTS).
```

> **Review checkpoint:** Verify join logic matches upstream tables in the contract. Confirm churn score derivation aligns with the contract's `derivation` field.

**Step 2 — Generate governance artifacts:**

```
#02_design/<product_name>_contract.yaml
Generate masking policies and DMF setup SQL based on the
governance rules in this contract.
Save to 03_deliver/masking_policies.sql and 03_deliver/dmf_setup.sql
```

> **Review checkpoint:** Every `pii: true` column has a masking policy. DMF schedule matches `sla.refresh_schedule`.

**Step 3 — Generate monitoring SQL:**

```
#02_design/<product_name>_contract.yaml
Generate monitoring and observability SQL — freshness SLAs,
quality checks, usage tracking, and alerts.
Save to 04_operate/monitoring_observability.sql
```

> **Review checkpoint:** Freshness threshold in generated SQL matches `sla.max_acceptable_lag_hours`.

**Step 4 — Deploy via Snow CLI:**

```
Deploy the dbt project to Snowflake using snow dbt deploy and run it.
Database: RETAIL_BANKING_DB, Schema: DATA_PRODUCTS
Then execute the model and show run results.
```

> **Review checkpoint:** `SELECT COUNT(*) FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK; -- Expected: ~1,000 rows`

**Step 5 — Validate the deployment:**

```
Validate the deployment — run dbt test, check row counts,
verify masking is applied to PII columns.
Report any test failures with remediation steps.
```

> **Review checkpoint:** All dbt tests pass. CoCo suggests targeted fixes for failures — no full regeneration needed.

**Advance when**: All 5 steps complete, dbt tests pass, masking verified.

---

## Phase 4: Operate

Monitoring SQL was generated in Phase 3 Step 3.

**Step 1 — Run monitoring:**

```
#04_operate/monitoring_observability.sql
Run this monitoring SQL and report:
1. Freshness SLA status for RETAIL_CUSTOMER_CHURN_RISK
   (is it within the 24-hour SLA from the contract?)
2. Quality gate results — PASS/FAIL per DMF rule
3. Top consumers over the last 7 days (role, user, query count)
```

> **Note:** If `04_operate/monitoring_observability.sql` doesn't exist yet, run Phase 3 Step 3 first, or copy from `04_operate/_example/monitoring_observability.sql`.

**Step 2 — Review RACI (optional):**

```
#04_operate/raci_template.md
#02_design/<product_name>_contract.yaml
Populate the RACI template for this data product using the
contract's owner, consumers, and domain information.
```

**Advance when**: Monitoring confirmed live, freshness and quality gates show PASS.

---

## Phase 5: Refine

Consumer feedback or regulatory changes drive contract evolution. Updating to v2 triggers regeneration of only the affected artifacts.

**Step 1 — Compare v1 and v2 contracts:**

```
#02_design/retail_customer_churn_risk_contract.yaml
#05_refine/_example/churn_risk_data_contract_v2.yaml
Compare v1 and v2. List:
- New columns added and their derivations
- Changed quality rules or SLA thresholds
- Any breaking changes that require migration SQL (ALTER TABLE)
```

> Once you have saved your updated v2 contract to `05_refine/churn_risk_data_contract_v2.yaml`, the tracker will advance Phase 5 to `[x]`.

**Step 2 — Run schema evolution SQL:**

```
#05_refine/_example/evolution_example.sql
Review and run the schema evolution SQL.
Confirm the ALTER TABLE adds the new columns without breaking existing consumers.
```

**Step 3 — Regenerate only affected artifacts:**

```
#05_refine/churn_risk_data_contract_v2.yaml
The data contract has been updated to v2 with two new columns
(customer_lifetime_value, financial_vulnerability_indicator).
Regenerate the dbt model, masking policies, and DMF setup
for the new columns only. Leave unchanged artifacts in place.
```

**Step 4 — Re-validate:**

```
Run dbt test against the updated model.
Verify the two new columns are present and all quality gates pass.
```

**Complete when**: All tests pass on the v2 model.
