# Prompt Instruction Guide: Contract-Driven Data Product Lifecycle

> **Purpose**: A reusable, step-by-step prompt guide for an AI assistant (e.g., Cortex Code) to build a governed data product on Snowflake using dbt — from discovery through deployment and operations.
>
> **Guiding Principles**:
> 1. **Verify everything with the user** at every stage before proceeding
> 2. **Maintain a TODO.md** and mark progress after every intervention
> 3. **Mark with comments** after every intervention — both in TODO.md and in generated code
>
> **Reference Implementation**: Adaptable to any domain (FSI, Healthcare, Retail, etc.)

---

## Table of Contents

**Part I — For Field Teams (Strategy & Adoption)**

1. [Cortex Code Skills for Data Products](#1-cortex-code-skills-for-data-products)
2. [The prompt.md — Guardrails & Rules for CoCo](#2-the-promptmd--guardrails--rules-for-coco)
3. [Developer Experience — How CoCo Uplifts the SDLC](#3-developer-experience--how-coco-uplifts-the-sdlc)

**Part II — Lifecycle Execution (Step-by-Step)**

4. [Operating Protocol](#4-operating-protocol)
5. [Phase 0: Setup & Prerequisites](#5-phase-0-setup--prerequisites)
6. [Phase 1: Discover](#6-phase-1-discover)
7. [Phase 2: Design](#7-phase-2-design)
8. [Phase 3: Deliver](#8-phase-3-deliver)
9. [Phase 4: Deploy](#9-phase-4-deploy)
10. [Phase 5: Validate](#10-phase-5-validate)
11. [Phase 6: Operate](#11-phase-6-operate)
12. [Phase 7: Cleanup](#12-phase-7-cleanup)
13. [Error Playbook](#13-error-playbook)
14. [Checklist Summary](#14-checklist-summary)

---

# Part I — For Field Teams (Strategy & Adoption)

---

## 1. Cortex Code Skills for Data Products

### The Idea

A **skill** in Cortex Code is a reusable instruction set that CoCo can invoke when a specific task is triggered. Think of skills as specialized "modes" — each one knows how to handle one phase of the data product lifecycle.

Instead of one giant prompt, you decompose the lifecycle into **discrete skills** that map 1:1 to lifecycle phases. This gives you:

- **Modularity** — Update one skill without breaking others
- **Reusability** — Same skills work across different data products (churn risk, fraud detection, credit scoring)
- **Consistency** — Every team member gets the same guardrails and patterns
- **Auditability** — Each skill's output is traceable back to the contract

### Recommended Skills Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   DATA PRODUCT CANVAS                    │
│              (Business requirements input)                │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│  SKILL: contract-generator                                │
│  Trigger: "Generate a data contract from this canvas"     │
│  Input:   Canvas image or markdown                        │
│  Output:  ODCS v2.2 YAML                                  │
│  Type:    AI (interprets business intent)                  │
└──────────────────────┬──────────────────────────────────┘
                       │
          ┌────────────┼────────────┬──────────────┐
          ▼            ▼            ▼              ▼
┌──────────────┐┌──────────────┐┌──────────────┐┌──────────────┐
│ SKILL:       ││ SKILL:       ││ SKILL:       ││ SKILL:       │
│ model-sql    ││ schema-yml   ││ masking-     ││ dmf-setup    │
│ generator    ││ generator    ││ policy-gen   ││ generator    │
│              ││              ││              ││              │
│ Type: AI     ││ Type: TPL    ││ Type: TPL    ││ Type: TPL    │
│ (transforms) ││ (parse)      ││ (parse)      ││ (parse)      │
└──────┬───────┘└──────┬───────┘└──────┬───────┘└──────┬───────┘
       │               │               │               │
       ▼               ▼               ▼               ▼
┌──────────────────────────────────────────────────────────┐
│  SKILL: test-generator                                    │
│  Trigger: "Generate tests for this data product"          │
│  Input:   Contract quality_rules + business_rules         │
│  Output:  Singular test SQL files                         │
│  Type:    Template (deterministic)                         │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│  SKILL: deployer                                          │
│  Trigger: "Deploy this data product"                      │
│  Input:   dbt project directory                           │
│  Output:  Snowflake DBT PROJECT object + test results     │
│  Type:    Orchestration (snow dbt deploy → execute → test)│
└──────────────────────────────────────────────────────────┘
```

### AI vs Template — When to Use Which

| Skill | Type | Why |
|-------|------|-----|
| **contract-generator** | AI | Interprets business intent from canvas, maps to ODCS structure |
| **model-sql generator** | AI | Writes transformation logic (CTEs, joins, scoring algorithms) |
| **schema-yml generator** | Template | Deterministic: column name → test type mapping from contract |
| **masking-policy generator** | Template | Deterministic: PII column + authorized roles → policy DDL |
| **dmf-setup generator** | Template | Deterministic: quality rule type → DMF function mapping |
| **test-generator** | Template | Deterministic: business rule condition → singular test SQL |
| **deployer** | Orchestration | Runs `snow dbt deploy` → `execute run` → `execute test` in sequence |

**Key insight for field teams**: Only **transformation logic** needs AI. Everything else is a deterministic parser. This means 5 of 7 skills produce identical output for identical input — no hallucination risk, fully auditable.

### How to Build a Skill

Skills in Cortex Code are markdown files placed in a known location. Each skill has:

```markdown
# Skill: {skill-name}

## Trigger
When the user asks to: "{trigger phrase}"

## Inputs
- {what the skill needs}

## Instructions
1. {step-by-step instructions for CoCo to follow}
2. ...

## Output
- {what the skill produces}

## Guardrails
- {rules the skill must follow}
```

**Example — masking-policy-generator skill**:

```markdown
# Skill: masking-policy-generator

## Trigger
When the user asks to generate masking policies from a data contract.

## Inputs
- Path to ODCS v2.2 contract YAML

## Instructions
1. Parse the contract's `schema.properties` section
2. Find all columns where `pii: true`
3. For each PII column, read its `masking_policy` block
4. Generate a CREATE OR REPLACE MASKING POLICY statement:
   - Use IS_ROLE_IN_SESSION() for each authorized role (NOT CURRENT_ROLE())
   - Default return: '***MASKED***'
5. Generate ALTER TABLE statements to apply the policy
6. Present output to user for review before saving

## Output
- masking_policies.sql

## Guardrails
- NEVER use CURRENT_ROLE() — always IS_ROLE_IN_SESSION()
- ALWAYS verify authorized roles list with user
- ALWAYS add [INTERVENTION] comment with timestamp
```

### Field Team Action Items

1. **Inventory your lifecycle** — Map your team's data product delivery process to phases
2. **Identify skill boundaries** — Each phase where input/output is clear = one skill
3. **Classify AI vs Template** — Only use AI skills where interpretation is needed
4. **Build incrementally** — Start with contract-generator + model-sql generator, add others over time
5. **Share across teams** — Skills are portable; one team's masking-policy-generator works for all

---

## 2. The prompt.md — Guardrails & Rules for CoCo

### The Idea

A `prompt.md` file at the root of your project acts as **standing instructions** for Cortex Code. Every time CoCo starts a session in that project directory, it reads `prompt.md` and follows those rules for the entire session.

This is your **governance layer** — it ensures CoCo behaves consistently across team members, sessions, and data products.

### What Goes in prompt.md

| Section | Purpose | Example |
|---------|---------|---------|
| **Identity** | Who CoCo is in this context | "You are a data product engineer building governed data products on Snowflake" |
| **Operating Rules** | Non-negotiable behaviors | "Verify with user before every phase transition" |
| **Naming Conventions** | Standard names for objects | "Tables: UPPER_SNAKE_CASE, Policies: {TABLE}_{COLUMN}_MASK" |
| **Quality Gates** | Minimum standards | "All required columns must have not_null tests" |
| **Forbidden Patterns** | Anti-patterns to avoid | "Never use CURRENT_ROLE() in masking policies" |
| **File Structure** | Expected project layout | "Models in 03_deliver/dbt_project/models/" |
| **Technology Choices** | Stack decisions | "Use native dbt tests only — no external packages" |
| **Progress Tracking** | How to track work | "Maintain TODO.md, mark [x] after every intervention" |

### Reference prompt.md

```markdown
# prompt.md — Data Product Lifecycle Rules

## Identity
You are a data product engineer using Cortex Code to build governed, 
contract-driven data products on Snowflake. You follow the ODCS v2.2 
standard and deploy via Snowflake-native dbt.

## Operating Rules
1. VERIFY with the user before:
   - Proceeding to a new lifecycle phase
   - Creating or dropping any Snowflake object
   - Finalizing any generated artifact
2. MAINTAIN TODO.md at the project root:
   - Update after every intervention
   - Use checkboxes: `- [ ]` (pending) / `- [x]` (done)
   - Record timestamps, row counts, and test results
3. COMMENT every change:
   - SQL: `-- [INTERVENTION] YYYY-MM-DD: description`
   - YAML: `# [INTERVENTION] YYYY-MM-DD: description`
4. NEVER proceed if a quality gate fails without user acknowledgment

## Data Contract Standard
- Use ODCS v2.2 specification
- Contract YAML is the SINGLE SOURCE OF TRUTH for all code generation
- Every output column must trace back to a contract property
- Every test must trace back to a contract quality_rule or business_rule

## Snowflake Conventions
- Database naming: {DOMAIN}_{FUNCTION}_DB (e.g., SALES_ANALYTICS_DB)
- Schema naming: RAW (sources), DATA_PRODUCTS (outputs), GOVERNANCE, MONITORING
- Table naming: UPPER_SNAKE_CASE matching the data product name
- Warehouse: {DOMAIN}_WH, size XSMALL, auto-suspend 300s
- Role: Use actual role from SELECT CURRENT_ROLE() — never assume

## dbt Rules (Snowflake-native)
- NO external packages (no packages.yml, no dbt_utils)
- NO env_var() or Jinja variables in profiles.yml — use literal values
- NO schema overrides in model config or dbt_project.yml
- NO password field in profiles.yml — Snowflake handles authentication
- Profiles.yml account format: ORG-ACCOUNT_NAME (get from SQL query)
- Use CTE-based transformation pattern (source → aggregate → flag → score → final)
- All tests must be native: not_null, unique, accepted_values, or singular SQL

## Masking Policies
- Use IS_ROLE_IN_SESSION() — NEVER CURRENT_ROLE()
- Policy naming: {COLUMN}_MASK (e.g., EMAIL_ADDRESS_MASK)
- Default masked value: '***MASKED***'
- Always verify authorized roles with user before applying

## Data Metric Functions (DMFs)
- Schedule: TRIGGER_ON_CHANGES
- Required DMFs: NULL_COUNT (on required columns), DUPLICATE_COUNT (on PK), 
  ROW_COUNT, FRESHNESS (on timestamp columns)
- Optional: UNIQUE_COUNT on business key columns

## Quality Gates (must pass before marking phase complete)
- All required columns: 0 NULLs
- Primary key: 0 duplicates
- Score/range columns: all within [min, max] from contract
- Enum columns: all values in allowed set from contract
- Business rules: 0 violations
- Masking: verified via POLICY_REFERENCES
- DMFs: verified via DATA_METRIC_FUNCTION_REFERENCES

## Forbidden Patterns
- CURRENT_ROLE() in masking policies
- env_var() in Snowflake-native profiles.yml
- +schema: in dbt_project.yml models config
- schema= in dbt model config block
- External package dependencies (dbt_utils, dbt_expectations, etc.)
- Hardcoded passwords in any file
- Dropping objects without user confirmation
```

### How Field Teams Should Use This

1. **Place `prompt.md` in the project root** — CoCo reads it automatically
2. **Customize per domain** — FSI teams might add compliance rules; Healthcare teams add HIPAA rules
3. **Version control it** — Treat it like code; PR reviews for changes
4. **Share a base template** — Start with the reference above, customize per team
5. **Evolve it** — After every engagement, capture new pitfalls in the Forbidden Patterns section

---

## 3. Developer Experience — How CoCo Uplifts the SDLC

### The Big Picture

Cortex Code doesn't replace the developer — it **removes the grunt work** so the developer focuses on **business logic and governance decisions**. Here's how it maps:

```
Traditional SDLC              With Cortex Code
─────────────────              ────────────────
Manual requirements gathering  → CoCo reads canvas, extracts structured requirements
Write contract from scratch    → CoCo generates ODCS v2.2 YAML, user validates
Hand-code dbt models           → CoCo generates CTE pipeline from contract derivations
Hand-code schema.yml           → CoCo parses contract → deterministic schema.yml
Hand-write masking policies    → CoCo parses contract PII columns → policy DDL
Hand-configure DMFs            → CoCo maps contract quality rules → DMF setup
Write tests manually           → CoCo maps business rules → singular test SQL
Deploy via manual SQL           → CoCo orchestrates snow dbt deploy/execute/test
Validate with ad-hoc queries   → CoCo runs validation suite, presents results
```

### What Changes for the Developer

| Activity | Before CoCo | With CoCo | Developer's Role |
|----------|-------------|-----------|-----------------|
| **Discovery** | Read docs, interview stakeholders, take notes | CoCo reads canvas image, extracts 10 sections, presents interpretation | Validate interpretation, add context CoCo missed |
| **Contract** | Write 500+ line YAML from scratch | CoCo generates YAML, user reviews | Review derivation logic, approve quality thresholds |
| **Model SQL** | Write 300+ lines of CTE SQL | CoCo generates from contract derivations | Review business logic, edge cases, performance |
| **Schema** | Manually map columns to tests | CoCo deterministically parses contract | Spot-check, add any custom tests |
| **Masking** | Look up syntax, write DDL | CoCo generates from contract PII flags | Confirm authorized roles |
| **DMFs** | Configure one by one via ALTER TABLE | CoCo generates full setup script | Review which columns get which DMFs |
| **Tests** | Write SQL for each business rule | CoCo converts contract conditions to test SQL | Review edge cases |
| **Deploy** | Run commands, debug errors | CoCo orchestrates, handles known errors | Monitor, approve phase transitions |
| **Validate** | Write ad-hoc queries | CoCo runs validation suite | Review results, accept/reject |

### The Developer Experience Shift

```
BEFORE: Developer is a WRITER
  → Spends 80% writing boilerplate, 20% on business logic
  
AFTER: Developer is a REVIEWER
  → Spends 20% reviewing generated code, 80% on business decisions
```

### Key SDLC Alignment Points

**1. Contract as Single Source of Truth**

The ODCS contract replaces scattered requirements docs, Jira tickets, and Slack conversations. Everything traces back to one YAML file:

```
Contract → Model SQL (derivation logic)
Contract → Schema.yml (column definitions, tests)
Contract → Masking Policies (PII flags, authorized roles)
Contract → DMF Setup (quality rules)
Contract → Tests (business rules)
Contract → Validation Queries (quality gates)
```

Change the contract → regenerate artifacts → redeploy. One source, consistent outputs.

**2. Verification-Driven Development**

CoCo is configured (via prompt.md) to pause and verify at every phase boundary. This means:
- No "I generated 1000 lines and hope it's right"
- Instead: "Here's what I'm about to generate. The model has 13 CTEs, 32 output columns, 5 risk flags. The scoring starts at base 20, adds/subtracts per the contract. Approve?"
- The developer stays in control without doing the writing

**3. Progressive Disclosure**

CoCo handles complexity in layers:
- **Phase 1**: Business person describes the problem (canvas)
- **Phase 2**: CoCo + architect formalize it (contract)
- **Phase 3**: CoCo generates all code (artifacts)
- **Phase 4**: CoCo deploys and tests (automation)
- **Phase 5**: CoCo validates against contract (quality)

Each phase adds technical detail, but the user only needs to understand and approve their layer.

**4. Error Prevention Over Error Recovery**

The prompt.md's Forbidden Patterns section means CoCo **never generates** known-bad patterns:
- No `CURRENT_ROLE()` in masking → no security gaps
- No `env_var()` in profiles.yml → no deploy failures
- No schema overrides → no concatenation bugs
- No external packages → no EAI dependency issues

These are lessons learned from real deployments, baked into the guardrails.

### How to Talk About This with Customers

**For Data Leaders**:
> "Cortex Code turns your data contract into a deployed, tested, governed data product 
> in a single session. The contract is the spec. CoCo is the builder. Your team is the 
> reviewer and approver."

**For Data Engineers**:
> "You define the business logic in the contract's derivation fields. CoCo generates the 
> dbt model, schema, tests, masking policies, and DMFs. You review, approve, and deploy 
> with `snow dbt deploy`. No boilerplate. No copy-paste errors."

**For Data Governance**:
> "Every column traces to a contract. Every test traces to a quality rule. Every masking 
> policy traces to a PII flag. The prompt.md enforces standards automatically — 
> IS_ROLE_IN_SESSION(), DMF scheduling, naming conventions. Governance by design, 
> not by audit."

**For Platform Teams**:
> "Skills are reusable across data products. prompt.md is version-controlled. The 
> deployer skill handles Snowflake-native dbt end-to-end. Your team maintains the 
> skills and guardrails; product teams consume them through CoCo."

### Field Team Action Items

1. **Run the reference implementation** — Use this guide end-to-end on a sample data product
2. **Customize prompt.md** — Add your customer's naming conventions, compliance requirements, and forbidden patterns
3. **Build 2-3 skills** — Start with contract-generator and model-sql-generator
4. **Demo the developer experience** — Show the canvas → contract → code → deploy → validate flow in a live session
5. **Capture new pitfalls** — Every engagement surfaces new errors; add them to the Error Playbook and Forbidden Patterns
6. **Measure the uplift** — Track time-to-deploy before/after CoCo adoption

---

# Part II — Lifecycle Execution (Step-by-Step)

---

## 4. Operating Protocol

These rules apply to **every phase** and **every interaction**. Follow them without exception.

### 4.1 Verify Before Acting

```
RULE: Never assume. Always confirm.
```

Before each phase transition or significant action:
- Present the user with a summary of what you are about to do
- List the files you will create or modify
- List the Snowflake objects you will create, alter, or drop
- Wait for explicit user approval ("yes", "go ahead", "proceed", etc.)
- If the user says "no" or raises concerns, stop and address them first

**Verification checkpoints** (minimum):
| Checkpoint | When |
|------------|------|
| Canvas interpretation | After reading the Data Product Canvas |
| Contract draft | Before finalizing the ODCS YAML |
| Code generation plan | Before generating any dbt code |
| Deployment target | Before running any SQL or `snow dbt deploy` |
| Test results review | After every test run |
| Phase completion | Before marking any phase as DONE |

### 4.2 Maintain TODO.md

```
RULE: TODO.md is the single source of progress truth.
```

- **Create** `TODO.md` at the project root at the start of the exercise
- **Structure** it with phases, tasks, and checkboxes (`- [ ]` / `- [x]`)
- **Update** it after every intervention:
  - Mark completed tasks with `[x]`
  - Add new tasks as they emerge
  - Record deployment metrics (row counts, test results, timestamps)
  - Add an `Objects Created` table tracking all Snowflake objects
- **Never** let TODO.md fall out of sync — update it before responding to the user

**TODO.md template**:

```markdown
# Data Product: [NAME]

## Progress Tracker

### Phase 0: Setup
- [ ] Verify prerequisites
- [ ] Run setup SQL

### Phase 1: Discover
- [ ] Read data product canvas
- [ ] Confirm interpretation with user

### Phase 2: Design
- [ ] Generate data contract (ODCS v2.2)
- [ ] Review and approve contract

### Phase 3: Deliver
- [ ] Generate dbt model SQL
- [ ] Generate schema.yml
- [ ] Generate masking policies
- [ ] Generate DMF setup
- [ ] Generate tests
- [ ] Create dbt project structure

### Phase 4: Deploy
- [ ] Deploy via Snowflake-native dbt
- [ ] Execute dbt run
- [ ] Execute dbt test

### Phase 5: Validate
- [ ] Run validation queries
- [ ] Verify data quality metrics
- [ ] Validate masking policies

### Phase 6: Operate
- [ ] Document RACI
- [ ] Set up monitoring

### Phase 7: Cleanup (optional)
- [ ] Run cleanup script

---

## Key Information
| Attribute | Value |
|-----------|-------|
| Owner     |       |
| Database  |       |
| Schema    |       |
| Table     |       |
| SLA       |       |
| Version   |       |

## Objects Created
| Object | Type | Location |
|--------|------|----------|
```

### 4.3 Comment After Every Intervention

```
RULE: Leave breadcrumbs. Every change gets a comment.
```

- In **SQL files**: Add `-- [INTERVENTION] YYYY-MM-DD: Description of change`
- In **YAML files**: Add `# [INTERVENTION] YYYY-MM-DD: Description of change`
- In **TODO.md**: Add timestamps and notes next to completed items
- In **dbt model configs**: Use `meta` tags to track contract version and owner

Example:
```sql
-- [INTERVENTION] YYYY-MM-DD: Removed schema override to fix concatenation issue
-- [INTERVENTION] YYYY-MM-DD: Replaced dbt_utils tests with native dbt tests
```

---

## 5. Phase 0: Setup & Prerequisites

### Objective
Ensure the Snowflake environment and local tools are ready.

### Steps

1. **Verify Snowflake connection**
   ```
   → ASK USER: "What is your Snowflake connection name for Cortex Code / Snow CLI?"
   → Run: SELECT CURRENT_ACCOUNT_NAME(), CURRENT_USER(), CURRENT_ROLE();
   → Record the values — you will need them for profiles.yml
   ```

2. **Check for existing resources**
   ```sql
   SHOW DATABASES LIKE '{PATTERN}';
   SHOW WAREHOUSES LIKE '{PATTERN}';
   ```
   → ASK USER: "Should I create these resources or do they already exist?"

3. **Run setup script** (if provided)
   ```
   → Read the setup.sql file
   → Summarize what it creates: database, schemas, warehouse, source tables, sample data
   → ASK USER: "This script will create [list]. Proceed?"
   → Execute the setup SQL
   → Verify: SELECT COUNT(*) FROM each source table
   ```

4. **Verify Snow CLI availability**
   ```bash
   snow --version
   snow connection list
   ```
   → Record the connection name for later use

5. **Update TODO.md** — Mark Phase 0 tasks as complete, record connection details

### Verification Checkpoint
```
→ ASK USER: "Setup complete. Here's what was created: [summary]. Ready for Discovery?"
```

---

## 6. Phase 1: Discover

### Objective
Understand the business problem, stakeholders, and data sources by reading the Data Product Canvas.

### Steps

1. **Read the Data Product Canvas**
   - Look for `01_discover/data_product_canvas.png` (or similar)
   - Extract all 10 sections:

   | # | Section | What to Extract |
   |---|---------|-----------------|
   | 1 | Business Problem | The pain point being solved |
   | 2 | Business Value | Expected outcomes and metrics |
   | 3 | Risks | What could go wrong |
   | 4 | KPIs | How success is measured |
   | 5 | Stakeholders | Who consumes the product and how often |
   | 6 | Key Entities | Core business objects |
   | 7 | Upstream Sources | Source systems and tables |
   | 8 | Downstream Dependencies | What consumes this product |
   | 9 | Org Impact | Teams affected |
   | 10 | Solution Approach | High-level technical approach |

2. **Present interpretation to user**
   ```
   → ASK USER: "Here's my interpretation of the canvas: [summary]. Is this correct? 
     Anything to add or change?"
   ```

3. **Confirm source tables exist in Snowflake**
   ```sql
   -- For each source table identified in the canvas:
   SELECT COUNT(*) FROM {database}.{raw_schema}.{table_name};
   ```

4. **Update TODO.md** — Mark Discovery tasks as complete

### Verification Checkpoint
```
→ ASK USER: "Discovery complete. I understand the business problem as: [1 sentence]. 
  The data product will use [N] source tables to produce [output description]. 
  Ready to design the contract?"
```

---

## 7. Phase 2: Design

### Objective
Create an Open Data Contract Standard (ODCS) v2.2 compliant YAML that serves as the single source of truth for all downstream code generation.

### Key Concept: Contract-Driven Data Products

```
DATA CONTRACT → INFORMS → Business Logic (dbt models)
                        → Quality Rules (DMFs, tests, freshness SLAs)
                        → Monitoring (Observability, alerts, usage tracking)
                        → Masking Policies (PII protection, role-based access)

"Define once in the contract → Generate consistently across all outputs"
```

### Steps

1. **Generate the ODCS v2.2 contract YAML**

   The contract must include these sections:

   | Section | Purpose |
   |---------|---------|
   | `info` | Title, version, owner, description, tags |
   | `servers` | Target Snowflake environment (database, schema, warehouse, role) |
   | `upstream_tables` | Source tables with schema references and keys |
   | `schema.properties` | Every output column with type, description, derivation logic, constraints |
   | `quality_rules` | Completeness, uniqueness, range checks, row count thresholds |
   | `business_rules` | Cross-column validation rules (e.g., risk tier aligns with score) |
   | `sla` | Freshness hours, update frequency, availability target |
   | `access` | Classification, restricted columns, authorized roles (full/masked/no access) |
   | `lineage` | Input tables → Output table mapping |
   | `stakeholders` | Consumers with frequency and use cases |

2. **Column derivation logic is critical**
   - For each derived column, write the derivation in plain English or pseudo-SQL
   - Include thresholds, enum values, and boundary conditions
   - This derivation logic becomes the specification for AI-generated transformation SQL

   Example:
   ```yaml
   {score_column}:
     type: integer
     description: Calculated composite score (0-100, higher = more risk)
     derivation: |
       BASE SCORE: Start at 20
       RISK FACTORS (add points):
       - {risk_flag_1}: +20 points
       - {risk_flag_2}: +20 points
       PROTECTIVE FACTORS (subtract points):
       - {protective_factor}: -10 points
       Cap final score between 0 and 100
     minimum: 0
     maximum: 100
   ```

3. **Mark PII columns explicitly**
   ```yaml
   {pii_column_name}:
     pii: true
     masking_policy:
       name: {PII_COLUMN}_MASK
       authorized_roles:
         - {authorized_role_1}
         - {authorized_role_2}
   ```

4. **Present the contract to user for review**
   ```
   → ASK USER: "Here's the data contract. Please review:
     - [N] output columns defined
     - [N] quality rules
     - [N] business rules
     - SLA: [freshness] refresh, [availability]% availability
     - PII columns: [list] with masking policies
     Is this correct? Any changes needed?"
   ```

5. **Save to** `02_design/{data_product_name}_contract.yaml` (or equivalent path)

6. **Update TODO.md** — Mark Design tasks as complete

### Verification Checkpoint
```
→ ASK USER: "Contract finalized at [path]. This will drive all code generation. 
  Ready to generate dbt code?"
```

---

## 8. Phase 3: Deliver

### Objective
Generate all dbt and SQL artifacts from the data contract. The contract is the single source of truth.

### Key Concept: Code Generation — AI vs Template

```
Data Contract → Contract Parser → 4 outputs:
  ├── model.sql          (AI-Generated: Cortex AI/LLM for transformation logic)
  ├── schema.yml         (Template-Based: Deterministic parsing)
  ├── masking_policies.sql (Template-Based: Deterministic parsing)
  └── dmf_setup.sql      (Template-Based: Deterministic parsing)

"Only transformation logic uses AI — all other outputs are deterministic parsers"
```

### Step 8.1: Generate dbt Model SQL

**Pattern**: CTE-based transformation pipeline

```sql
-- CTE Structure (example — adapt to your domain):
-- 1. source_{entity_1}     → Raw primary entity data
-- 2. source_{entity_2}     → Raw secondary entity, filtered
-- 3. source_{entity_3}     → Raw supporting data
-- 4. source_{entity_4}     → Raw engagement/activity data
-- 5. source_{entity_5}     → Raw event/issue data
-- 6. {entity_1}_{entity_2} → Aggregated metrics per primary entity
-- 7. {entity_1}_{entity_3} → Aggregated metrics per primary entity
-- 8. {entity_1}_engagement → Engagement scoring
-- 9. {entity_1}_events     → Event aggregation
-- 10. combined             → JOIN all CTEs on primary key
-- 11. flags                → Apply boolean risk/quality driver flags
-- 12. scored               → Calculate composite score
-- 13. final                → Add tier, primary driver, 
--                            recommended action, metadata

SELECT * FROM final
```

**Rules for model SQL generation**:
- Use `{{ source('schema', 'table') }}` for source references
- Use `{{ config(materialized='table', ...) }}` block at the top
- Include `meta` tags with owner, contract version, description
- Add `tags` from the contract's `info.tags`
- **Do NOT include** `schema=` in the config block (causes concatenation issues)
- Use `LEAST()` / `GREATEST()` for capping scores to valid ranges
- Build JSON risk driver objects with `OBJECT_CONSTRUCT()`

**Save to**: `03_deliver/dbt_project/models/{model_name}.sql`

### Step 8.2: Generate schema.yml

**Parse from contract**: sources, columns, descriptions, tests

```yaml
version: 2

sources:
  - name: RAW
    database: "{{ var('database') }}"
    schema: "{{ var('raw_schema') }}"
    tables:
      # One entry per upstream_table in the contract

models:
  - name: {model_name}
    description: # From contract info.description
    columns:
      # One entry per schema.properties column
      - name: {primary_key}
        description: # From contract
        data_tests:
          - not_null
          - unique
```

**Critical rule**: Use **native dbt tests only** — do NOT use `dbt_utils` or any external packages.

| Contract Rule | dbt Test |
|---------------|----------|
| `unique: true` | `unique` |
| `required` columns | `not_null` |
| `enum` values | `accepted_values: values: [...]` |
| Range checks | Use singular tests (custom SQL files) |

For range checks (e.g., score between 0-100), create **singular test SQL files** instead of `dbt_utils.accepted_range`:

```sql
-- tests/test_{score_column}_valid_range.sql
SELECT *
FROM {{ ref('{model_name}') }}
WHERE {score_column} < 0 OR {score_column} > 100
```

**Save to**: `03_deliver/dbt_project/models/schema.yml`

### Step 8.3: Generate Masking Policies

**Parse from contract**: columns where `pii: true` and `masking_policy` is defined

```sql
CREATE OR REPLACE MASKING POLICY {database}.{schema}.{policy_name}
AS (val STRING)
RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('{role1}') THEN val
    WHEN IS_ROLE_IN_SESSION('{role2}') THEN val
    ELSE '***MASKED***'
  END;
```

**Critical**: Use `IS_ROLE_IN_SESSION()` (not `CURRENT_ROLE()`) — this correctly handles role hierarchy.

**Save to**: `03_deliver/masking_policies.sql`

### Step 8.4: Generate DMF Setup

**Parse from contract**: quality_rules → map to Snowflake Data Metric Functions

| Contract Rule Type | DMF |
|-------------------|-----|
| `completeness` | `SNOWFLAKE.CORE.NULL_COUNT` |
| `uniqueness` | `SNOWFLAKE.CORE.DUPLICATE_COUNT` / `UNIQUE_COUNT` |
| `row_count` | `SNOWFLAKE.CORE.ROW_COUNT` |
| `freshness` (SLA) | `SNOWFLAKE.CORE.FRESHNESS` |

```sql
ALTER TABLE {table} SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

ALTER TABLE {table} ADD DATA METRIC FUNCTION 
  SNOWFLAKE.CORE.NULL_COUNT ON ({primary_key});
```

**Save to**: `03_deliver/dmf_setup.sql`

### Step 8.5: Generate Singular Tests

Create one SQL file per `business_rule` in the contract:

```sql
-- tests/test_{rule_name}.sql
-- Contract rule: {rule.description}
SELECT *
FROM {{ ref('{model_name}') }}
WHERE NOT ({rule.condition})
```

**Save to**: `03_deliver/dbt_project/tests/`

### Step 8.6: Create dbt Project Structure

```
03_deliver/dbt_project/
├── dbt_project.yml
├── profiles.yml
├── models/
│   ├── {model_name}.sql
│   └── schema.yml
└── tests/
    ├── test_{business_rule_1}.sql
    ├── test_{business_rule_2}.sql
    └── ... (one per business rule + range check)
```

**dbt_project.yml** — critical settings:
```yaml
name: '{project_name}'
version: '1.0.0'
config-version: 2
profile: '{profile_name}'

model-paths: ["models"]
test-paths: ["tests"]

vars:
  database: '{DATABASE}'
  schema: '{SCHEMA}'
  raw_schema: '{RAW_SCHEMA}'

models:
  {project_name}:
    +materialized: table
    +tags: [...]
    # ⚠️ Do NOT add +schema here — causes concatenation issue
```

**profiles.yml** — for Snowflake-native dbt:
```yaml
# ⚠️ CRITICAL: Snowflake-native dbt rules:
# 1. NO env_var() — not supported in Snowflake-native execution
# 2. NO password/authenticator — Snowflake handles auth
# 3. Use LITERAL values for account and user — no Jinja expressions
# 4. account format: ORG-ACCOUNT_NAME (with hyphen)

{profile_name}:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: {ORG}-{ACCOUNT_NAME}   # ← Get from SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME()
      user: {USER}                     # ← Get from SELECT CURRENT_USER()
      role: {ROLE}                     # ← Get from SELECT CURRENT_ROLE()
      database: {DATABASE}
      warehouse: {WAREHOUSE}
      schema: {SCHEMA}
      threads: 4
```

### Step 8.7: Verify and Present to User

```
→ ASK USER: "Code generation complete. Here's what was created:
  - Model SQL: [N] lines, [N] CTEs, [N] output columns
  - Schema YAML: [N] column definitions, [N] tests
  - Masking Policies: [N] policies for PII columns
  - DMF Setup: [N] metrics configured
  - Singular Tests: [N] test files
  
  Do you want me to walk through any of these? Ready to deploy?"
```

### Update TODO.md
Mark all Deliver tasks as complete. Record file paths and line counts.

---

## 9. Phase 4: Deploy

### Objective
Deploy the dbt project to Snowflake using Snowflake-native dbt (`snow dbt deploy`).

### Pre-Flight Checks

1. **Get actual Snowflake values** (these go into profiles.yml):
   ```sql
   SELECT 
     CURRENT_ORGANIZATION_NAME() AS org,
     CURRENT_ACCOUNT_NAME() AS account,
     CURRENT_USER() AS user_name,
     CURRENT_ROLE() AS role_name;
   ```

2. **Confirm profiles.yml uses the correct values**
   ```
   → ASK USER: "Your Snowflake account is [org]-[account], user is [user], role is [role]. 
     Is this correct for deployment?"
   ```

3. **Verify no external package dependencies**
   - Check there is NO `packages.yml` file
   - Check schema.yml has NO references to `dbt_utils` or other external packages
   - External packages require External Access Integration (EAI) — avoid if possible

### Deploy Steps

1. **Deploy the dbt project**
   ```bash
   snow dbt deploy {PROJECT_NAME} \
     --source {LOCAL_DBT_PROJECT_PATH} \
     --database {DATABASE} \
     --schema {SCHEMA} \
     -c {CONNECTION_NAME}
   ```

2. **If deploy fails** → See [Error Playbook](#10-error-playbook)

3. **Execute dbt run**
   ```bash
   snow dbt execute \
     -c {CONNECTION_NAME} \
     --database {DATABASE} \
     --schema {SCHEMA} \
     {PROJECT_NAME} run
   ```
   → Verify: check for "1 of 1 OK" in output
   → Record row count from output

4. **Execute dbt test**
   ```bash
   snow dbt execute \
     -c {CONNECTION_NAME} \
     --database {DATABASE} \
     --schema {SCHEMA} \
     {PROJECT_NAME} test
   ```
   → Record pass/fail counts
   → Investigate any failures

5. **Apply masking policies** (if not handled by dbt):
   ```sql
   ALTER TABLE {database}.{schema}.{table}
     MODIFY COLUMN {column}
     SET MASKING POLICY {database}.{schema}.{policy_name};
   ```

6. **Configure DMFs** (if not handled by dbt):
   ```sql
   ALTER TABLE {table} SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
   ALTER TABLE {table} ADD DATA METRIC FUNCTION 
     SNOWFLAKE.CORE.NULL_COUNT ON ({column});
   ```

### Deploy Verification

```sql
-- Confirm table exists and has data
SELECT COUNT(*) FROM {database}.{schema}.{table};

-- Confirm masking policy is attached
SELECT * FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => '{database}.{schema}.{table}',
  REF_ENTITY_DOMAIN => 'TABLE'
));

-- Confirm DMFs are active
SELECT * FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
  REF_ENTITY_NAME => '{database}.{schema}.{table}',
  REF_ENTITY_DOMAIN => 'TABLE'
));

-- Confirm dbt project object exists
SHOW DBT PROJECTS IN SCHEMA {database}.{schema};
```

### Present Results to User

```
→ ASK USER: "Deployment complete. Results:
  - Table: [row count] rows
  - Tests: [N]/[M] passed
  - Masking: [policy] applied to [column]
  - DMFs: [list] configured
  - Failed tests: [list with explanations]
  
  Any concerns? Ready to proceed to validation?"
```

### Update TODO.md
Mark all Deploy tasks as complete. Add Deployment Summary with metrics and test results.

---

## 10. Phase 5: Validate

### Objective
Run comprehensive validation to confirm the data product meets contract specifications.

### Validation Queries

Run each query and present results to user:

1. **Row count and category distribution**
   ```sql
   SELECT {category_column}, COUNT(*) AS cnt,
     ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
   FROM {database}.{schema}.{table}
   GROUP BY {category_column}
   ORDER BY cnt DESC;
   ```

2. **Score range validation**
   ```sql
   SELECT MIN({score_column}), MAX({score_column}), AVG({score_column})
   FROM {database}.{schema}.{table};
   ```

3. **NULL checks on required fields**
   ```sql
   SELECT 
     COUNT_IF({primary_key} IS NULL) AS null_pk,
     COUNT_IF({score_column} IS NULL) AS null_score,
     COUNT_IF({category_column} IS NULL) AS null_category
   FROM {database}.{schema}.{table};
   ```

4. **Uniqueness check**
   ```sql
   SELECT {primary_key}, COUNT(*) AS cnt
   FROM {database}.{schema}.{table}
   GROUP BY {primary_key}
   HAVING COUNT(*) > 1;
   ```

5. **Business rule: category aligns with score**
   ```sql
   -- Adapt the thresholds and category values to match your contract
   SELECT * FROM {database}.{schema}.{table}
   WHERE NOT (
     ({category_column} = '{TIER_1}' AND {score_column} BETWEEN 0 AND 25) OR
     ({category_column} = '{TIER_2}' AND {score_column} BETWEEN 26 AND 50) OR
     ({category_column} = '{TIER_3}' AND {score_column} BETWEEN 51 AND 75) OR
     ({category_column} = '{TIER_4}' AND {score_column} BETWEEN 76 AND 100)
   );
   ```

6. **Masking policy test**
   ```sql
   -- Switch to a non-authorized role and verify masking works
   USE ROLE {non_authorized_role};
   SELECT {pii_column} FROM {database}.{schema}.{table} LIMIT 5;
   -- Should see '***MASKED***'
   ```

### Present Results to User

```
→ ASK USER: "Validation results:
  [table of test results: name, status, details]
  
  Known issues:
  - [list any known deviations with explanations]
  
  All critical checks passed. Satisfied with results?"
```

### Update TODO.md
Mark Validate tasks as complete. Record test result summary table.

---

## 11. Phase 6: Operate

### Objective
Establish ongoing operations: RACI accountability, monitoring, and refresh schedules.

### Steps

1. **Document RACI Matrix**

   | Role | Discover | Design | Deliver | Operate |
   |------|----------|--------|---------|---------|
   | Product Owner | A | A | I | A |
   | Architecture | C | R | C | I |
   | Data Producer | R | C | R | R |
   | Platform | I | I | C | R |
   | Governance | C | R | I | C |
   | Consumer | R | C | I | I |

   (R=Responsible, A=Accountable, C=Consulted, I=Informed)

2. **Set up scheduling** (if applicable)
   ```sql
   -- Create a Snowflake Task to run the dbt project on schedule
   CREATE OR REPLACE TASK {database}.{schema}.refresh_{model_name}
     WAREHOUSE = {warehouse}
     SCHEDULE = 'USING CRON 0 6 * * * UTC'
   AS
     EXECUTE DBT PROJECT {database}.{schema}.{project_name} run;
   
   ALTER TASK {database}.{schema}.refresh_{model_name} RESUME;
   ```

3. **Set up alerting** (if applicable)
   ```sql
   -- Alert on freshness SLA breach
   CREATE OR REPLACE ALERT {database}.{schema}.freshness_alert
     WAREHOUSE = {warehouse}
     SCHEDULE = 'USING CRON 0 7 * * * UTC'
     IF (EXISTS (
       SELECT 1 FROM {database}.{schema}.{table}
       WHERE score_calculated_at < DATEADD('hour', -{sla_freshness_hours}, CURRENT_TIMESTAMP())
     ))
     THEN
       CALL SYSTEM$SEND_EMAIL(...);
   ```

4. **Update TODO.md** — Mark Operate tasks as complete

### Verification Checkpoint
```
→ ASK USER: "Operations setup complete:
  - RACI documented
  - Refresh schedule: [schedule]
  - Alerting: [configured/not configured]
  
  Anything else for operations?"
```

---

## 12. Phase 7: Cleanup

### Objective
Tear down all resources created during the exercise (for demo/workshop environments).

### Steps

1. **Confirm with user**
   ```
   → ASK USER: "⚠️ This will permanently delete ALL resources created during the exercise:
     - Database: {database} (and all schemas, tables, views)
     - Warehouse: {warehouse}
     - All masking policies, DMFs, alerts, tasks
     
     Are you absolutely sure? Type 'yes' to confirm."
   ```

2. **Run cleanup in order** (dependencies matter):
   ```sql
   -- Step 1: Remove alerts (depends on warehouse)
   ALTER ALERT {alert} SUSPEND;
   DROP ALERT IF EXISTS {alert};
   
   -- Step 2: Remove DMFs from tables (must be before dropping table)
   ALTER TABLE {table} DROP DATA METRIC FUNCTION 
     SNOWFLAKE.CORE.NULL_COUNT ON ({column});
   
   -- Step 3: Drop database (cascades schemas, tables, policies)
   DROP DATABASE IF EXISTS {database};
   
   -- Step 4: Drop warehouse
   DROP WAREHOUSE IF EXISTS {warehouse};
   ```

3. **Update TODO.md** — Mark Cleanup as complete

---

## 13. Error Playbook

Common errors encountered during the exercise and their fixes.

### E1: Role Does Not Exist

```
Error: "Role 'X' does not exist or is not accessible"
```

**Fix**: Query `SELECT CURRENT_ROLE()` and update profiles.yml with the actual role.

### E2: Jinja `{{ target.* }}` Undefined in Snowflake-native dbt

```
Error: "Could not render {{ target.account }}: 'target' is undefined"
```

**Fix**: Snowflake-native dbt does NOT support Jinja expressions like `{{ target.account }}` or `{{ env_var() }}` in profiles.yml. Use literal values only:
```yaml
account: ORG-ACCOUNT_NAME   # NOT {{ target.account }}
user: USERNAME               # NOT {{ env_var('SNOWFLAKE_USER') }}
# NO password field          # Auth handled by Snowflake
```

Get the literal values with:
```sql
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();
SELECT CURRENT_USER();
```

### E3: Schema Name Concatenation

```
Problem: Table created in SCHEMA_SCHEMA instead of SCHEMA
Example: {SCHEMA}_{SCHEMA} instead of {SCHEMA}
```

**Fix**: dbt concatenates `default_schema` + `custom_schema`. Remove the custom schema override:
- In model SQL config: Remove `schema='{SCHEMA}'`
- In dbt_project.yml: Remove `+schema: {SCHEMA}` under models
- The default schema from profiles.yml is sufficient

After fixing, redeploy and drop the stale table in the wrong schema:
```sql
DROP TABLE IF EXISTS {database}.{wrong_schema}.{table};
```

### E4: External Package Dependency (dbt_utils)

```
Problem: packages.yml requires External Access Integration (EAI) for package resolution
```

**Fix**: Eliminate external dependencies entirely:
- Delete `packages.yml`
- Replace `dbt_utils.accepted_range` with singular test SQL files
- Replace `dbt_utils.expression_is_true` with singular test SQL files
- Use only native dbt tests: `not_null`, `unique`, `accepted_values`

### E5: Row Count Below Threshold (Known Data Condition)

```
Problem: Test expects 1000 rows but source data filtering (e.g., KYC_STATUS = 'VERIFIED') 
reduces count to below threshold
```

**Fix**: This is not a code bug. Document it as a known data condition:
- Adjust the threshold in the test to match actual data
- Or document the gap between contract expectation and sample data reality
- In production, the full data set would meet the threshold

### E6: Deploy Fails with Version Conflict

```
Problem: `snow dbt deploy` reports version conflict
```

**Fix**: Each deploy creates a new VERSION$N automatically. If the previous version had issues:
1. Redeploy (creates VERSION$N+1)
2. The new version becomes active
3. Drop stale objects from the old version if needed

---

## 14. Checklist Summary

Use this checklist at the end of the exercise to confirm everything is complete.

### Artifacts Checklist

| # | Artifact | Path | Status |
|---|----------|------|--------|
| 1 | Data Product Canvas | `01_discover/data_product_canvas.png` | |
| 2 | Data Contract (ODCS v2.2) | `02_design/{contract_name}.yaml` | |
| 3 | dbt Model SQL | `03_deliver/dbt_project/models/{model}.sql` | |
| 4 | Schema YAML | `03_deliver/dbt_project/models/schema.yml` | |
| 5 | Masking Policies SQL | `03_deliver/masking_policies.sql` | |
| 6 | DMF Setup SQL | `03_deliver/dmf_setup.sql` | |
| 7 | Singular Tests | `03_deliver/dbt_project/tests/*.sql` | |
| 8 | dbt_project.yml | `03_deliver/dbt_project/dbt_project.yml` | |
| 9 | profiles.yml | `03_deliver/dbt_project/profiles.yml` | |
| 10 | TODO.md | `TODO.md` (project root) | |
| 11 | RACI Matrix | `04_operate/raci_template.md` | |
| 12 | Cleanup Script | `06_cleanup/cleanup.sql` | |

### Snowflake Objects Checklist

| # | Object | Type | Expected Location |
|---|--------|------|-------------------|
| 1 | Target Table | TABLE | `{DB}.{SCHEMA}.{TABLE}` |
| 2 | Masking Policy | POLICY | `{DB}.{SCHEMA}.{POLICY}` |
| 3 | DMFs | METRIC | Attached to target table columns |
| 4 | DBT PROJECT | PROJECT | `{DB}.{SCHEMA}.{PROJECT}` |
| 5 | Warehouse | WAREHOUSE | Account level |

### Quality Gates Checklist

| # | Gate | Criteria |
|---|------|----------|
| 1 | All required columns NOT NULL | 0 NULLs |
| 2 | Primary key unique | 0 duplicates |
| 3 | Score ranges valid | All within [min, max] |
| 4 | Enum values valid | All in allowed set |
| 5 | Business rules hold | 0 violations |
| 6 | Masking policy active | Verified via POLICY_REFERENCES |
| 7 | DMFs configured | Verified via DATA_METRIC_FUNCTION_REFERENCES |
| 8 | Row count meets threshold | ≥ contract minimum |

---

## Appendix A: Lifecycle Diagram

```
    ┌──────────┐
    │ DISCOVER │ ← Canvas, stakeholder interviews
    └────┬─────┘
         │
    ┌────▼─────┐
    │  DESIGN  │ ← ODCS v2.2 Contract (single source of truth)
    └────┬─────┘
         │
    ┌────▼─────┐
    │ DELIVER  │ ← AI + Template code generation from contract
    └────┬─────┘
         │
    ┌────▼─────┐
    │  DEPLOY  │ ← snow dbt deploy → execute → test
    └────┬─────┘
         │
    ┌────▼─────┐
    │ VALIDATE │ ← Quality gates, masking, DMF verification
    └────┬─────┘
         │
    ┌────▼─────┐
    │ OPERATE  │ ← RACI, scheduling, alerting
    └────┬─────┘
         │
    ┌────▼─────┐
    │  REFINE  │ ← Feedback loop back to DISCOVER
    └──────────┘
```

## Appendix B: Key Snowflake Commands Reference

```bash
# Deploy dbt project
snow dbt deploy {PROJECT} --source {PATH} --database {DB} --schema {SCHEMA} -c {CONN}

# Execute dbt run
snow dbt execute -c {CONN} --database {DB} --schema {SCHEMA} {PROJECT} run

# Execute dbt test
snow dbt execute -c {CONN} --database {DB} --schema {SCHEMA} {PROJECT} test

# List dbt projects
snow dbt list -c {CONN} --database {DB} --schema {SCHEMA}
```

## Appendix C: Prompt Template for Starting a New Data Product

Copy-paste this prompt to start a new data product lifecycle:

```
You are an AI assistant helping build a contract-driven data product on Snowflake.

OPERATING RULES:
1. VERIFY everything with the user before proceeding to the next phase
2. MAINTAIN TODO.md — update it after every intervention with checkmarks and timestamps
3. COMMENT every change — add [INTERVENTION] markers in all files you modify

LIFECYCLE:
Follow this order: Setup → Discover → Design → Deliver → Deploy → Validate → Operate

For each phase:
- Explain what you're about to do
- List the files/objects you'll create or modify
- Wait for user approval
- Execute the phase
- Present results
- Update TODO.md
- Ask if user is ready for the next phase

TECHNICAL STACK:
- Contract: ODCS v2.2 YAML
- Code: dbt (Snowflake-native via `snow dbt deploy`)
- Quality: DMFs (NULL_COUNT, DUPLICATE_COUNT, FRESHNESS, ROW_COUNT)
- Security: Masking policies with IS_ROLE_IN_SESSION()
- Tests: Native dbt tests only (no external packages)

AVOID THESE PITFALLS:
- No env_var() or Jinja expressions in profiles.yml for Snowflake-native dbt
- No custom schema overrides in dbt model config (causes name concatenation)
- No dbt_utils or external packages (require EAI)
- No CURRENT_ROLE() in masking policies (use IS_ROLE_IN_SESSION())
- No password field in profiles.yml for Snowflake-native execution

BEGIN:
Read the Data Product Canvas at [PATH] and start the Discovery phase.
```

---

*Generated as a reusable guide for contract-driven data product lifecycle on Snowflake.*
