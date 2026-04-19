# Data Product Lifecycle Accelerator

## On Load — Do This Immediately

**Do not greet the user. Do not ask what they want. Do not explain what you are about to do. Your first output must be the lifecycle tracker followed by the current phase's prompts. Run steps 1–3 now.**

**1. Detect state** — check whether each of these files exists:

| Phase | File |
|-------|------|
| 0. Setup | `00_setup/setup.sql` |
| 1. Discover | `01_discover/data_product_canvas.png` |
| 2. Design | `02_design/retail_customer_churn_risk_contract.yaml` |
| 3. Deliver | `03_deliver/dbt_project/models/retail_customer_churn_risk.sql` |
| 4. Operate | `04_operate/monitoring_observability.sql` |
| 5. Refine | `05_refine/churn_risk_data_contract_v2.yaml` |

Mark each phase:
- `[✓]` — file exists (artifacts in place)
- `[→]` — previous phase done but this phase's artifacts not yet generated — **this is the current phase**
- `[ ]` — pending (earlier phase not complete)

**2. Display the tracker** with the detected markers:

```
╔══════════════════════════════════════════════════════╗
║       DATA PRODUCT LIFECYCLE TRACKER                 ║
╠══════════════════════════════════════════════════════╣
║  [✓] 0. SETUP     — environment ready                ║
║  [✓] 1. DISCOVER  — canvas confirmed                 ║
║  [→] 2. DESIGN    — current                          ║
║  [ ] 3. DELIVER   — pending                          ║
║  [ ] 4. OPERATE   — pending                          ║
║  [ ] 5. REFINE    — pending                          ║
╚══════════════════════════════════════════════════════╝
Current phase: <N> — <PHASE NAME>
```

**3. Show a short step menu for the current phase** — display a numbered list of step names only. Do NOT show full prompt text yet. Use this format:

> **Next up: Phase N — PHASE NAME** (X steps)
> 1. First step title
> 2. Second step title
> ...
>
> **Choose how to proceed:**
> - Type a step number (e.g. `2`) to use the default prompt for that step
> - Describe what you want (e.g. `Deliver: create dbt model`) to run a custom prompt instead
> - Type `done` when this phase is complete to advance the tracker

Short step titles per phase to use in the menu:

| Phase | Step titles |
|-------|------------|
| 0 Setup | 1. Run setup.sql in Snowsight (Steps 1–4) |
| 1 Discover | 1. Review the canvas |
| 2 Design | 1. Review the example contract  ·  2. (Optional) Generate your own contract |
| 3 Deliver | 1. Generate dbt project  ·  2. Governance artifacts (masking + DMF)  ·  3. Monitoring SQL  ·  4. Deploy via Snow CLI  ·  5. Validate |
| 4 Operate | 1. Run monitoring SQL  ·  2. (Optional) Populate RACI |
| 5 Refine | 1. Compare v1 vs v2  ·  2. Run evolution SQL  ·  3. Regenerate affected artifacts  ·  4. Re-validate |

When the user picks a step number or says "next", display the full prompt text for that step from the Phase Prompts section below — one step at a time.
When the user types a custom instruction (e.g. "Deliver: create dbt model"), execute it directly without showing the default prompt.

---

## Description

Launches an interactive lifecycle tracker and guides the user through all five phases of the data product lifecycle — Discover, Design, Deliver, Operate, Refine — using Cortex Code only. No Streamlit, no manual LLM prompts.

Each phase has ready-to-run CoCo prompts. The user runs the prompts, confirms completion, and the tracker advances.

## Trigger Keywords

- `$dplc-accelerator`
- "start lifecycle"
- "guide me through the data product lifecycle"
- "next step"
- "where am I in the lifecycle"
- "what should I do next"

## Phase Map

| # | Phase | Folder | Key Skills |
|---|-------|--------|------------|
| 0 | Setup | `00_setup/` | — (run `setup.sql` in Snowsight) |
| 1 | Discover | `01_discover/` | — (review canvas, confirm requirements) |
| 2 | Design | `02_design/` | `$contract-generator`, `$contract-verifier` |
| 3 | Deliver | `03_deliver/` | `$data-product-generator` (orchestrates all below) |
| 4 | Operate | `04_operate/` | — (run monitoring SQL) |
| 5 | Refine | `05_refine/` | `$contract-verifier`, `$data-product-generator` |

---

## Phase Prompts

### Phase 0: Setup

> No CoCo prompts needed. Open `00_setup/setup.sql` in Snowsight and run Steps 1–4.
> Verify with Step 5 (row count check). Return here when setup is complete.

**Advance when**: All five source tables exist in `RETAIL_BANKING_DB.RAW`.

---

### Phase 1: Discover

> Discover is pre-assumed — the Data Product Canvas is already in hand. This phase is context only.

**Review the canvas:**

```
#01_discover/data_product_canvas.png
Summarise this Data Product Canvas:
1. What data product are we building and what business goal does it serve?
2. Who are the consumers and what decisions does this data support?
3. What source systems and tables do we need?
4. What quality and governance commitments are required (SLAs, PII, regulatory)?
5. Are there any ambiguities to resolve before designing the contract?
```

**Advance when**: Canvas is understood and requirements are confirmed. No files to generate.

---

### Phase 2: Design

*Sprint Day 1 — Design*

> A data contract is a machine-readable YAML (ODCS v2.2) that formalises the canvas. It is the single source of truth — every artifact in Phase 3 is derived from it.

**Step 2a — Review the example contract:**

```
#02_design/_example/churn_risk_data_contract.yaml
Summarise this data contract:
- Schema (column count, key output fields, PII fields)
- Quality rules (completeness, range, freshness SLA)
- Governance (masking policies, regulatory tags)
- Upstream source tables
Confirm all upstream tables exist in Snowflake before we proceed to Deliver.
```

> **Before advancing Phase 2:** Copy `02_design/_example/churn_risk_data_contract.yaml` to `02_design/<product_name>_contract.yaml` and adapt it, OR generate your own via Step 2b. The tracker advances once your contract exists at `02_design/<product_name>_contract.yaml`.

**Step 2b — (Optional) Generate your own contract from the canvas:**

```
$contract-generator
#01_discover/data_product_canvas.png
Generate an ODCS v2.2 data contract from this canvas.
Use 02_design/_example/churn_risk_data_contract.yaml as the structure reference.
Save to 02_design/<product_name>_contract.yaml
```

> **Review checkpoint:** Confirm all upstream tables are verified against Snowflake. Confirm all PII columns are flagged and quality rules are testable.

**Advance when**: Contract is reviewed (or generated), upstream tables verified, and ready for code generation.

---

### Phase 3: Deliver

*Sprint Day 1–2 — Deliver*

> Five sequential prompts. Each builds on the previous. Run them in order and review the output before continuing.

**Prompt 1 — Generate the dbt project:**

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

> **Review checkpoint:** Verify the join logic in the model SQL matches the upstream tables in the contract. Confirm the churn score derivation formula aligns with the contract's `derivation` field.

**Prompt 2 — Generate governance artifacts:**

```
#02_design/retail_customer_churn_risk_contract.yaml
Generate masking policies and DMF setup SQL based on the
governance rules in this contract.
Save to 03_deliver/masking_policies.sql and 03_deliver/dmf_setup.sql
```

> **Review checkpoint:** Every column with `pii: true` must have a corresponding masking policy. The DMF schedule must match `sla.refresh_schedule` from the contract.

**Prompt 3 — Generate monitoring SQL:**

```
#02_design/<product_name>_contract.yaml
Generate monitoring and observability SQL — freshness SLAs,
quality checks, usage tracking, and alerts.
Save to 04_operate/monitoring_observability.sql
```

> **Review checkpoint:** Confirm the freshness threshold in the generated SQL matches `sla.max_acceptable_lag_hours` from the contract.

**Prompt 4 — Deploy via Snow CLI:**

```
Deploy the dbt project to Snowflake using snow dbt deploy and run it.
Database: RETAIL_BANKING_DB, Schema: DATA_PRODUCTS
Then execute the model and show run results.
```

> **Review checkpoint:** Verify the table exists and has rows:
> ```sql
> SELECT COUNT(*) FROM RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;
> -- Expected: ~1,000 rows
> ```

**Prompt 5 — Validate the deployment:**

```
Validate the deployment — run dbt test, check row counts,
verify masking is applied to PII columns.
Report any test failures with remediation steps.
```

> **Review checkpoint:** All dbt tests should pass. If any fail, CoCo consults the Error Playbook and suggests a targeted fix — no full regeneration needed.

**Advance when**: All 5 prompts complete, all dbt tests pass, masking verified.

---

### Phase 4: Operate

*Sprint Day 2 — Operate*

> Monitoring SQL was generated in Prompt 3 above. Run it to confirm the product is operating correctly.

**Step 4a — Run monitoring:**

```
#04_operate/monitoring_observability.sql
Run this monitoring SQL and report:
1. Freshness SLA status for RETAIL_CUSTOMER_CHURN_RISK
   (is it within the 24-hour SLA from the contract?)
2. Quality gate results — PASS/FAIL per DMF rule
3. Top consumers over the last 7 days (role, user, query count)
```

> **Note:** If `04_operate/monitoring_observability.sql` doesn't exist yet, run Phase 3 Prompt 3 first, or copy from `04_operate/_example/monitoring_observability.sql` as a starting point.

**Step 4b — Review RACI (optional):**

```
#04_operate/raci_template.md
#02_design/retail_customer_churn_risk_contract.yaml
Populate the RACI template for this data product using the
contract's owner, consumers, and domain information.
```

**Advance when**: Monitoring is confirmed live, freshness and quality gates show PASS.

---

### Phase 5: Refine

*Post-sprint — Refine*

> Consumer feedback or regulatory changes drive contract evolution. Because all artifacts are generated from the contract, updating to v2 triggers regeneration of only the affected artifacts.

**Step 5a — Compare v1 and v2 contracts:**

```
#02_design/retail_customer_churn_risk_contract.yaml
#05_refine/_example/churn_risk_data_contract_v2.yaml
Compare v1 and v2. List:
- New columns added and their derivations
- Changed quality rules or SLA thresholds
- Any breaking changes that require migration SQL (ALTER TABLE)
```

> Once you have saved your updated v2 contract to `05_refine/churn_risk_data_contract_v2.yaml`, the tracker will advance Phase 5 to `[✓]`.

**Step 5b — Run schema evolution SQL:**

```
#05_refine/_example/evolution_example.sql
Review and run the schema evolution SQL.
Confirm the ALTER TABLE adds the new columns without breaking existing consumers.
```

**Step 5c — Regenerate only affected artifacts:**

```
#05_refine/churn_risk_data_contract_v2.yaml
The data contract has been updated to v2 with two new columns
(customer_lifetime_value, financial_vulnerability_indicator).
Regenerate the dbt model, masking policies, and DMF setup
for the new columns only. Leave unchanged artifacts in place.
```

**Step 5d — Re-validate:**

```
Run dbt test against the updated model.
Verify the two new columns are present and all quality gates pass.
```

**Complete when**: All tests pass on the v2 model. Lifecycle cycle complete.

---

## Rules

- **Never** suggest or reference `03_deliver/.streamlit/` — that path is not part of the guided workflow
- Always use `#file` prefix when referencing contract or SQL files in prompts
- Always confirm with the user before advancing to the next phase
- Use `cortex ctx task` / `cortex ctx step` to track progress across sessions
- Redisplay the tracker after every phase transition
- If the user asks "what's next" mid-phase, present the next unrun prompt within the current phase
- If the user asks about the Streamlit path, note it exists at `03_deliver/.streamlit/` for reference but direct them to use CoCo prompts above instead
