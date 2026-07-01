# SF Data Product Lifecycle Plugin

Complete data product lifecycle automation for Snowflake.

## Installation

### For Local Development
```bash
cd data-products-lifecycle-fsi-example
cortex plugin add .
```

### For Publishing to Snowhouse
See instructions below for uploading to Snowflake Skill Catalog.

## What's Included

13 production-ready skills for building governed data products:

### Core Orchestration
- **dplc-accelerator** — Lifecycle tracker (Discover → Design → Deliver → Operate → Refine)
- **data-product-generator** — Orchestrates full deliver phase

### Contract Management
- **contract-generator** — Generate ODCS v2.2 contracts from Canvas/Avro/Confluence
- **contract-parser** — Parse and validate contracts
- **contract-verifier** — Verify contract against Snowflake tables

### Code Generation
- **model-sql-generator** — Generate dbt SQL models
- **schema-yml-generator** — Generate dbt schema.yml
- **test-generator** — Generate dbt tests

### Governance
- **masking-policy-generator** — Generate PII masking policies
- **dmf-setup-generator** — Generate Data Metric Functions for quality gates

### Analytics
- **semantic-view-generator** — Generate semantic views
- **marketplace-listing-generator** — Generate Internal Marketplace listings

### Utilities
- **capture-feedback** — Capture user feedback on generated artifacts

## Usage

### Start the Lifecycle
```
$sf-data-product-lifecycle:dplc-accelerator
```

Or just describe what you want:
```
Generate a data contract from this canvas
Create dbt models from this contract
Generate masking policies for PII columns
```

The agent will auto-detect and invoke the appropriate skill.

## Publishing to Snowhouse (Internal Distribution)

1. Open Cortex Code Desktop
2. Agent Settings → Plugins
3. Find `sf-data-product-lifecycle` → Click **Publish to Skills Catalog**
4. Target database: `SHARED` (or your Snowhouse standard)
5. Target schema: `SKILLS` or `PLUGINS`
6. Grant access to: `PUBLIC` (all employees)
7. Copy the returned URI: `snow://plugin_catalog/...`

## Publishing to Customer Catalogs

Customers can clone this repo and publish to their own account:

```bash
git clone https://github.com/srini86/data-products-lifecycle-fsi-example
cd data-products-lifecycle-fsi-example
cortex plugin publish . --database SHARED --schema PLUGINS --grant-to PUBLIC
```

Then share the `snow://` URI with their team.

## Version History

- **1.0.0** — Initial release with 13 skills for full lifecycle automation
