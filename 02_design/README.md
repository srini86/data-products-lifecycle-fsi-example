# Phase 2: Design

## What this phase produces

- **Data Contract (YAML)** — An ODCS v2.2 specification that defines the data product's schema, business rules, quality expectations, SLAs, and governance metadata.

## Reference example

`_example/churn_risk_data_contract.yaml` — a complete FSI churn-risk data contract you can use as a starting point.

## How to complete Phase 2

Before the lifecycle tracker can advance past Design, you need a contract file at:

```
02_design/<product_name>_contract.yaml
```

Two ways to create it:

### Option A — Copy and adapt the example
```bash
cp 02_design/_example/churn_risk_data_contract.yaml \
   02_design/retail_customer_churn_risk_contract.yaml
```
Then open the file in CoCo and customise it for your product.

### Option B — Generate from the canvas
In Cortex Code:
```
$contract-generator
#01_discover/data_product_canvas.png
Generate an ODCS v2.2 data contract from this canvas.
Use 02_design/_example/churn_risk_data_contract.yaml as the structure reference.
Save to 02_design/<product_name>_contract.yaml
```

Once the file exists at `02_design/<product_name>_contract.yaml`, the tracker will mark Phase 2 as `[✓]` and unlock Phase 3.
