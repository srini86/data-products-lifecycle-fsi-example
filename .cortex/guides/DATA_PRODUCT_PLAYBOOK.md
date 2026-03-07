# Data Product Playbook — Quick Reference

> Contract-driven lifecycle for governed data products on Snowflake.
> Standing rules: see `prompt.md` at the project root.
> Skill definitions: `.cortex/skills/` (project-level, auto-loaded by Cortex Code).

## Lifecycle Phases

| Phase | Folder | Key Action | Skill(s) |
|-------|--------|------------|----------|
| 0. Setup | `00_setup/` | Create DB, schemas, warehouse, sample data | — (run `setup.sql`) |
| 1. Discover | `01_discover/` | Read Data Product Canvas, confirm with user | `$contract-generator` |
| 2. Design | `02_design/` | Generate ODCS v2.2 contract YAML | `$contract-generator`, `$contract-verifier` |
| 3. Deliver | `03_deliver/` | Generate all dbt + governance artifacts | `$data-product-generator` (orchestrates all below) |
| 4. Deploy | — | `dbt run` + `dbt test` via Snowflake-native dbt | — |
| 5. Validate | — | Run quality gates from contract | `$contract-verifier` |
| 6. Operate | `04_operate/` | Monitoring, alerting, RACI | — (run `monitoring_observability.sql`) |
| 7. Cleanup | `06_cleanup/` | Tear down demo resources | — (run `cleanup.sql`) |

## Deliver Phase — Artifact Generation Order

1. `$contract-parser` — Parse contract YAML into structured data
2. `$model-sql-generator` — dbt model SQL (AI-powered)
3. `$schema-yml-generator` — dbt schema.yml (template)
4. `$test-generator` — Singular dbt tests (template)
5. `$masking-policy-generator` — Masking policy DDL (template)
6. `$dmf-setup-generator` — Data Metric Functions setup (template)
7. `$semantic-view-generator` — Semantic view DDL (template)
8. `$marketplace-listing-generator` — Share + listing DDL (template)

## Key Principles

- Contract YAML is the **single source of truth** — all artifacts derive from it
- **Verify with the user** before creating/dropping Snowflake objects or moving phases
- **Quality gates must pass** before marking a phase complete (see `prompt.md`)
- Track progress via `cortex ctx task` / `cortex ctx step`

## Evolution (Phase 5: Refine)

When adding columns or changing logic:
1. Update the contract YAML first (bump version)
2. Regenerate affected artifacts using the relevant `$skill`
3. Re-run quality gates
