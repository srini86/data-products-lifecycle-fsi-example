# Retail Customer Churn Risk - RACI Matrix

> This RACI matrix shows how different teams collaborated to deliver the **Retail Customer Churn Risk** data product through its lifecycle.

## Legend

| Code | Role | Description |
|------|------|-------------|
| **R** | Responsible | Performs the work |
| **A** | Accountable | Owns the outcome (one per task) |
| **C** | Consulted | Provides input before decisions |
| **I** | Informed | Kept updated on progress |

---

## Teams Involved

| Role | Team | Key Person (Example) |
|------|------|---------------------|
| **Product Owner** | Retail Analytics | Alex Morgan (Data Product Manager) |
| **Data Engineer** | Data Engineering | Jordan Lee (Analytics Engineer) |
| **Platform Team** | DataOps | Sam Chen (Platform Engineer) |
| **Governance** | Risk & Compliance | Taylor Smith (Data Steward) |
| **Consumers** | Business Intelligence | Casey Brown (Retention Analyst) |
| **Stakeholders** | Retail Banking | Morgan Davis (Head of Retention) |

---

## DISCOVER: Identifying the Churn Risk Opportunity

| Activity | Product Owner | Data Engineer | Platform | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:--------:|:----------:|:---------:|:------------:|
| Identify churn prediction need | R | I | I | C | C | **A** |
| Define success KPIs (reduce churn by 15%) | R | C | I | C | C | **A** |
| Assess source data (customers, transactions, complaints) | C | R | C | I | I | I |
| Create Data Product Canvas | **A** | C | I | C | R | C |
| Prioritize on Q2 roadmap | **A** | I | I | C | I | C |

**Outcome:** Data Product Canvas created (`01_discover/data_product_canvas.yaml`)

---

## DESIGN: Defining the Churn Risk Contract

| Activity | Product Owner | Data Engineer | Platform | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:--------:|:----------:|:---------:|:------------:|
| Define 32 output columns (risk_score, risk_tier, etc.) | **A** | R | C | C | C | I |
| Specify SLA (daily refresh by 6 AM UTC) | **A** | C | R | I | I | I |
| Define quality rules (no nulls, valid ranges) | C | R | I | **A** | C | I |
| Specify masking (customer_name, email → PII) | C | C | I | **A** | I | I |
| Document source lineage (5 source tables) | I | R | C | **A** | I | I |
| Review & sign-off contract | **A** | C | C | R | C | I |

**Outcome:** Data Contract v1.0 created (`02_design/churn_risk_data_contract.yaml`)

---

## DELIVER: Building the Churn Risk Product

| Activity | Product Owner | Data Engineer | Platform | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:--------:|:----------:|:---------:|:------------:|
| Generate dbt model via Streamlit app | I | **A** | C | I | I | I |
| Build transformations (risk scoring logic) | I | **A** | C | I | I | I |
| Implement masking policies on PII columns | I | R | C | **A** | I | I |
| Set up DMFs (NULL_COUNT, FRESHNESS, etc.) | I | R | **A** | C | I | I |
| Create semantic view for Cortex Analyst | C | **A** | C | I | C | I |
| Publish to internal marketplace | **A** | R | C | C | I | I |
| Deploy to RETAIL_BANKING_DB.DATA_PRODUCTS | I | R | **A** | C | I | I |

**Outcome:** 
- dbt model deployed (`retail_customer_churn_risk.sql`)
- DMFs configured (`03_deliver/02_data_quality_dmf.sql`)
- Marketplace listing live

---

## OPERATE: Running the Churn Risk Product

| Activity | Product Owner | Data Engineer | Platform | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:--------:|:----------:|:---------:|:------------:|
| Monitor 24-hour freshness SLA | I | C | **A** | I | I | I |
| Monitor quality expectations (0 nulls, 0 duplicates) | I | C | **A** | R | I | I |
| Respond to SLA breach alerts | C | R | **A** | C | I | I |
| Track usage (retention_analyst, branch_manager roles) | **A** | I | R | I | I | C |
| Verify masking on customer_name, email | I | I | C | **A** | I | I |
| Monthly KPI report to Retail Banking | **A** | C | I | I | C | R |

**Outcome:** 
- Monitoring dashboard (`04_operate/monitoring_observability.sql`)
- 3 consumer roles actively querying
- 99.2% SLA compliance in Q2

---

## REFINE: Evolving to v2.0

| Activity | Product Owner | Data Engineer | Platform | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:--------:|:----------:|:---------:|:------------:|
| Gather feedback (need CLV, confidence scores) | **A** | I | I | I | R | C |
| Compliance request (vulnerability indicator for FCA) | C | I | I | **A** | I | R |
| Propose 6 new columns for v2.0 | **A** | C | I | C | R | C |
| Update data contract to v2.0 | **A** | R | I | C | C | I |
| Regenerate dbt model from updated contract | I | **A** | R | C | I | I |
| Archive v1.0 snapshot for audit | I | R | **A** | C | I | I |
| Add DMFs for new columns (CLV, confidence) | I | R | **A** | C | I | I |
| Communicate v2.0 changes to consumers | **A** | C | I | I | R | I |

**Outcome:** 
- Data Contract v2.0 (`05_refine/churn_risk_data_contract_v2.yaml`)
- 6 new columns: `estimated_clv`, `clv_tier`, `product_downgrade_flag`, `action_confidence_score`, `vulnerability_indicator`, `products_held_90d_ago`

---

## Summary: Who Owns What

| Stage | Accountable | Key Deliverable |
|-------|-------------|-----------------|
| **Discover** | Stakeholders → Product Owner | Data Product Canvas |
| **Design** | Product Owner + Governance | Data Contract v1.0 |
| **Deliver** | Data Engineer | Deployed model + DMFs |
| **Operate** | Platform Team | Monitoring & 99%+ SLA |
| **Refine** | Product Owner | Data Contract v2.0 |

---

## Key Collaboration Points

| Handoff | From | To | Artifact |
|---------|------|-----|----------|
| Business need → Technical spec | Stakeholders | Product Owner | Canvas |
| Canvas → Contract | Product Owner | Data Engineer | YAML contract |
| Contract → Code | Data Engineer | Platform Team | dbt model + DMFs |
| Monitoring → Feedback | Platform Team | Product Owner | Usage reports |
| Feedback → Evolution | Consumers | Product Owner | v2.0 requirements |

---

## Lessons Learned

1. **Governance early** - Involving compliance in Design prevented rework when FCA requirements emerged
2. **Contract as source of truth** - Regenerating code from contract made v2.0 evolution smooth
3. **Platform owns SLAs** - Clear accountability for monitoring reduced incident response time
4. **Consumer feedback loop** - Regular check-ins with retention analysts drove valuable v2.0 features
