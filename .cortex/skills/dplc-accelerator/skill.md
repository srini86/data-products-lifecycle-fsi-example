---
name: dplc-accelerator
description: "Interactive lifecycle tracker for the data product lifecycle. Detects current phase, shows what has been built, and guides through Discover, Design, Deliver, Operate, Refine with a step-by-step prompt menu. Use when: starting or resuming the data product lifecycle, checking phase progress. Triggers: $dplc-accelerator, start lifecycle, guide me through the data product lifecycle, next step, where am I in the lifecycle, what should I do next."
tools: ["read", "write", "ask_user_question", "snowflake_sql_execute", "skill"]
---

# Data Product Lifecycle Accelerator

## On Load — Do This Immediately

**Do not greet the user. Do not ask what they want. Do not explain what you are about to do. Your first output must be the lifecycle tracker and the step menu — then STOP and wait for user input. Do NOT execute any prompts, run any commands, or take any action until the user types a step number or custom instruction. Run steps 1–3 now, then stop.**

**1. Detect state** — check whether each of these files exists:

| Phase | Completion signal file |
|-------|------------------------|
| 0. Setup | `00_setup/setup.sql` |
| 1. Discover | `01_discover/data_product_canvas.png` |
| 2. Design | `02_design/retail_customer_churn_risk_contract.yaml` |
| 3. Deliver | `03_deliver/dbt_project/models/retail_customer_churn_risk.sql` |
| 4. Operate | `04_operate/monitoring_observability.sql` |
| 5. Refine | `05_refine/churn_risk_data_contract_v2.yaml` |

Mark each phase: `[x]` file exists · `[>]` current (previous done, this not yet) · `[ ]` pending

**2. Display the tracker:**

```
╔══════════════════════════════════════════════════════╗
║       DATA PRODUCT LIFECYCLE TRACKER                 ║
╠══════════════════════════════════════════════════════╣
║  [x] 0. SETUP     — environment ready                ║
║  [x] 1. DISCOVER  — canvas confirmed                 ║
║  [>] 2. DESIGN    — current                          ║
║  [ ] 3. DELIVER   — pending                          ║
║  [ ] 4. OPERATE   — pending                          ║
║  [ ] 5. REFINE    — pending                          ║
╚══════════════════════════════════════════════════════╝
Current phase: <N> — <PHASE NAME>
```

Then output a **"What's already been built"** block for every `[x]` phase (omit pending and current phases; omit the block entirely if no phases are complete):

```
What's already been built:
  [x] SETUP    — RETAIL_BANKING_DB (RAW, DATA_PRODUCTS, GOVERNANCE, MONITORING)
               DATA_PRODUCTS_WH · 5 source tables loaded

  [x] DISCOVER — 01_discover/data_product_canvas.png
               Requirements confirmed: Retail Customer Churn Risk

  [x] DESIGN   — 02_design/retail_customer_churn_risk_contract.yaml
               ODCS v2.2 contract with output columns, quality rules, PII masking policies

  [x] DELIVER  — 03_deliver/dbt_project/models/retail_customer_churn_risk.sql
               masking_policies.sql · dmf_setup.sql
               Deployed: RETAIL_BANKING_DB.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK

  [x] OPERATE  — 04_operate/monitoring_observability.sql
               Freshness SLA · quality gate · usage tracking

  [x] REFINE   — 05_refine/churn_risk_data_contract_v2.yaml
               Schema evolution applied, artifacts regenerated
```

**3. Show the step menu for the current phase** — step titles only, no prompt text. STOP after showing the menu and wait for user input.

> **Next up: Phase N — PHASE NAME** (X steps)
> 1. Step title
> 2. Step title
> ...
>
> **Choose how to proceed:**
> - Type a step number to run that step
> - Describe what you want (e.g. `Deliver: create dbt model`) to run a custom prompt
> - Type `done` when this phase is complete to advance the tracker

**After showing this menu: STOP. Do not proceed. Wait for user input.**

Step titles per phase:

| Phase | Step titles |
|-------|------------|
| 0 Setup | 1. Run setup.sql (Steps 1–4) |
| 1 Discover | 1. Review the canvas |
| 2 Design | 1. Review example contract · 2. Generate from canvas (optional) · 3. Generate from AVRO (optional) · 4. Generate from Confluence (optional) |
| 3 Deliver | 1. Generate dbt project · 2. Governance artifacts · 3. Monitoring SQL · 4. Deploy · 5. Validate |
| 4 Operate | 1. Run monitoring SQL · 2. Populate RACI (optional) |
| 5 Refine | 1. Compare v1 vs v2 · 2. Evolution SQL · 3. Regenerate artifacts · 4. Re-validate |

---

## Responding to User Input

**When user types a step number** (e.g. `1`):

Check `prompt.md` for `DPLC_MODE: DEMO`:
- **DEMO mode** (`DPLC_MODE: DEMO` is set): execute the step immediately — read `phase_prompts.md`, run the prompt, show output. No intermediate confirmation.
- **INTERACTIVE mode** (default, no flag): read `phase_prompts.md`, display the prompt text, and wait for the user to confirm or modify before executing.

**When user types a custom instruction** (e.g. `Deliver: create dbt model`):
Execute it directly without showing the default prompt.

**When user types `done`**:
Advance the tracker to the next phase, redisplay the full tracker, and show the new phase's step menu.

---

## Guardrails

- NEVER execute a step without showing the prompt text first and waiting for user confirmation
- NEVER advance the tracker without user typing `done`
- NEVER suggest or reference `03_deliver/.streamlit/` — not part of the guided workflow
- ALWAYS use `#file` prefix when referencing contract or SQL files in prompts
- ALWAYS redisplay the tracker after every phase transition
- If the user asks "what's next" mid-phase, show the next unrun step title only — do not execute it
