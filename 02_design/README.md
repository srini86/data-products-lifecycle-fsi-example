# Phase 2: Design

## What this phase produces

- **Data Contract (YAML)** — An ODCS v2.2 specification that defines the data product's schema, business rules, quality expectations, SLAs, and governance metadata.

## How to use Cortex Code

1. Provide your completed Data Product Canvas (from `01_discover/`) as input.
2. Ask CoCo to generate a data contract from the canvas.
3. Review and refine the generated contract with your domain experts.

```
Prompt CoCo:
  "Generate an ODCS v2.2 data contract from the canvas at
   01_discover/data_product_canvas.png"

Input:   01_discover/data_product_canvas.png (or equivalent)
Output:  02_design/<your_contract>.yaml
```

## Reference example

See `_example/churn_risk_data_contract.yaml` for a complete FSI churn-risk data contract generated using this workflow.
