# Phase 2: Design

## What this phase produces

- **Data Contract (YAML)** — An ODCS v2.2 specification that defines the data product's schema, business rules, quality expectations, SLAs, and governance metadata.

## How to use Cortex Code

1. Provide your completed Data Product Canvas (from `01_discover/`) as input.
2. Use the `data_contract_generator` skill to produce a draft contract.
3. Review and refine the generated contract with your domain experts.

```
CoCo Skill: data_contract_generator
Input:       01_discover/data_product_canvas.png (or equivalent)
Output:      02_design/<your_contract>.yaml
```

## Reference example

See `_example/churn_risk_data_contract.yaml` for a complete FSI churn-risk data contract generated using this workflow.
