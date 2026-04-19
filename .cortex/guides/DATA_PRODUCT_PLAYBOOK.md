# Data Product Playbook — Quick Reference

> Start with `$dplc-accelerator` — the skill guides you through every phase with ready-to-run prompts.

## Lifecycle Phases

| Phase | Folder | Key Action | Skill(s) |
|-------|--------|------------|----------|
| 0. Setup | `00_setup/` | Create DB, schemas, warehouse, and sample data | — (run `setup.sql` in Snowsight) |
| 1. Discover | `01_discover/` | Review Data Product Canvas, confirm requirements | — |
| 2. Design | `02_design/` | Generate and verify ODCS v2.2 contract YAML | `$contract-generator`, `$contract-verifier` |
| 3. Deliver | `03_deliver/` | Generate all dbt + governance artifacts, deploy, validate | `$data-product-generator` (orchestrates all below) |
| 4. Operate | `04_operate/` | SLA monitoring, quality gates, usage tracking | — (run `monitoring_observability.sql`) |
| 5. Refine | `05_refine/` | Evolve contract, regenerate affected artifacts | `$contract-verifier`, `$data-product-generator` |

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
- **Quality gates must pass** before marking a phase complete
- Track progress via `cortex ctx task` / `cortex ctx step`

## Refine (Phase 5)

When adding columns or changing logic:
1. Update the contract YAML first (bump version)
2. Regenerate only the affected artifacts using the relevant `$skill`
3. Re-run quality gates
