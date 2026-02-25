# Phase 5: Refine

## What this phase produces

- **Updated data contract** — New version reflecting usage feedback, schema changes, or business rule updates.
- **Evolution SQL** — Migration scripts for backward-compatible schema changes.

## How to use Cortex Code

1. Gather feedback from consumers (usage patterns, quality issues, feature requests).
2. Use CoCo to update the contract version and regenerate artifacts.

```
Prompt CoCo:
  "Update the data contract to v2.0 with these new columns: ..."
  "Regenerate the dbt schema.yml and tests for the updated contract"
```

## Reference example

See `_example/` for the FSI churn-risk evolution artifacts:

- `churn_risk_data_contract_v2.yaml` — Version 2 contract with refinements.
- `evolution_example.sql` — Schema evolution migration script.
