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

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DATA PRODUCT LIFECYCLE                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│   │ DISCOVER │───▶│  DESIGN  │───▶│ DELIVER  │───▶│ OPERATE  │───▶│  REFINE  │  │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│        │               │               │               │               │         │
│        ▼               ▼               ▼               ▼               ▼         │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│   │  Canvas  │    │ Contract │    │dbt Model │    │Monitoring│    │Contract  │  │
│   │  (YAML)  │    │  (YAML)  │    │   +DMFs  │    │ +Alerts  │    │  v2.0    │  │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              SNOWFLAKE PLATFORM                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   SOURCE LAYER                 PRODUCT LAYER                 CONSUMPTION LAYER  │
│   ─────────────                ─────────────                 ─────────────────  │
│                                                                                  │
│   ┌───────────┐               ┌─────────────────┐            ┌───────────────┐  │
│   │ CUSTOMERS │──┐            │                 │        ┌──▶│Retention Team │  │
│   ├───────────┤  │            │  RETAIL_CUSTOMER│        │   ├───────────────┤  │
│   │ ACCOUNTS  │──┤            │   _CHURN_RISK   │        │   │Branch Managers│  │
│   ├───────────┤  │   dbt +    │                 │  Share │   ├───────────────┤  │
│   │TRANSACTIONS──┼──Cortex───▶│  • 38 columns   │────────┼──▶│Data Scientists│  │
│   ├───────────┤  │            │  • Risk scores  │        │   ├───────────────┤  │
│   │ DIGITAL_  │──┤            │  • CLV tiers    │        │   │Cortex Analyst │  │
│   │ENGAGEMENT │  │            │  • Masked PII   │        │   └───────────────┘  │
│   ├───────────┤  │            │                 │        │                      │
│   │COMPLAINTS │──┘            └─────────────────┘        │   ┌───────────────┐  │
│   └───────────┘                       │                  └──▶│  Marketplace  │  │
│                                       │                      └───────────────┘  │
│                                       ▼                                         │
│                              ┌─────────────────┐                                │
│                              │   MONITORING    │                                │
│                              │  • DMFs         │                                │
│                              │  • Freshness    │                                │
│                              │  • Quality      │                                │
│                              │  • Usage        │                                │
│                              └─────────────────┘                                │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Teams Involved

| Role | Team | Key Person (Example) | Focus |
|------|------|---------------------|-------|
| **Product Owner** | Retail Analytics | Alex Morgan | Business outcomes, prioritization |
| **Architecture** | Enterprise Architecture | Jamie Rivera | Standards, patterns, technical design |
| **Producer** | Data Engineering | Jordan Lee | Builds and delivers the data product |
| **Platform** | DataOps | Sam Chen | Infrastructure, monitoring, SLAs |
| **Governance** | Risk & Compliance | Taylor Smith | Quality rules, masking, compliance |
| **Consumer** | Business Intelligence | Casey Brown | Uses the data product |

---

## DISCOVER: Identifying the Churn Risk Opportunity

| Activity | Product Owner | Architecture | Producer | Platform | Governance | Consumer |
|----------|:-------------:|:------------:|:--------:|:--------:|:----------:|:--------:|
| Identify churn prediction need | **A** | I | I | I | C | R |
| Define success KPIs (reduce churn by 15%) | **A** | I | C | I | C | R |
| Assess source data availability | C | C | **A** | C | I | I |
| Evaluate technical feasibility | C | **A** | R | C | I | I |
| Create Data Product Canvas | **A** | C | C | I | C | R |
| Prioritize on Q2 roadmap | **A** | C | I | I | C | C |

**Outcome:** Data Product Canvas created (`01_discover/data_product_canvas.yaml`)

---

## DESIGN: Defining the Churn Risk Contract

| Activity | Product Owner | Architecture | Producer | Platform | Governance | Consumer |
|----------|:-------------:|:------------:|:--------:|:--------:|:----------:|:--------:|
| Define 32 output columns (schema) | **A** | C | R | C | C | C |
| Design transformation patterns | C | **A** | R | C | I | I |
| Specify SLA (daily refresh by 6 AM UTC) | **A** | C | C | R | I | I |
| Define quality rules (no nulls, valid ranges) | C | C | R | I | **A** | C |
| Specify masking (customer_name → PII) | C | C | C | I | **A** | I |
| Document source lineage (5 tables) | I | C | R | C | **A** | I |
| Review & sign-off contract | **A** | R | C | C | R | C |

**Outcome:** Data Contract v1.0 created (`02_design/churn_risk_data_contract.yaml`)

---

## DELIVER: Building the Churn Risk Product

| Activity | Product Owner | Architecture | Producer | Platform | Governance | Consumer |
|----------|:-------------:|:------------:|:--------:|:--------:|:----------:|:--------:|
| Generate dbt model via Streamlit app | I | C | **A** | C | I | I |
| Build transformations (risk scoring) | I | C | **A** | C | I | I |
| Code review against standards | I | **A** | R | C | I | I |
| Implement masking policies | I | C | R | C | **A** | I |
| Set up DMFs (NULL_COUNT, FRESHNESS) | I | C | R | **A** | C | I |
| Create semantic view for Cortex Analyst | C | C | **A** | C | I | C |
| Publish to internal marketplace | **A** | I | R | C | C | I |
| Deploy to production | I | C | R | **A** | C | I |

**Outcome:** 
- dbt model deployed (`retail_customer_churn_risk.sql`)
- DMFs configured (`03_deliver/02_data_quality_dmf.sql`)
- Marketplace listing live

---

## OPERATE: Running the Churn Risk Product

| Activity | Product Owner | Architecture | Producer | Platform | Governance | Consumer |
|----------|:-------------:|:------------:|:--------:|:--------:|:----------:|:--------:|
| Monitor 24-hour freshness SLA | I | I | C | **A** | I | I |
| Monitor quality expectations | I | I | C | **A** | R | I |
| Respond to SLA breach alerts | C | I | R | **A** | C | I |
| Track usage & adoption metrics | **A** | I | I | R | I | C |
| Verify masking compliance | I | I | I | C | **A** | I |
| Optimize query performance | I | C | R | **A** | I | I |
| Monthly KPI report to business | **A** | I | C | I | I | R |

**Outcome:** 
- Monitoring dashboard (`04_operate/monitoring_observability.sql`)
- 3 consumer roles actively querying
- 99.2% SLA compliance in Q2

---

## REFINE: Evolving to v2.0

| Activity | Product Owner | Architecture | Producer | Platform | Governance | Consumer |
|----------|:-------------:|:------------:|:--------:|:--------:|:----------:|:--------:|
| Gather feedback (need CLV, confidence) | **A** | I | I | I | I | R |
| Compliance request (FCA vulnerability) | C | I | I | I | **A** | I |
| Propose 6 new columns for v2.0 | **A** | C | C | I | C | R |
| Review schema evolution approach | C | **A** | R | C | C | I |
| Update data contract to v2.0 | **A** | C | R | I | C | C |
| Regenerate dbt model from contract | I | C | **A** | R | C | I |
| Archive v1.0 snapshot for audit | I | I | R | **A** | C | I |
| Add DMFs for new columns | I | I | R | **A** | C | I |
| Communicate changes to consumers | **A** | I | C | I | I | R |

**Outcome:** 
- Data Contract v2.0 (`05_refine/churn_risk_data_contract_v2.yaml`)
- 6 new columns: `estimated_clv`, `clv_tier`, `product_downgrade_flag`, `action_confidence_score`, `vulnerability_indicator`, `products_held_90d_ago`

---

## Summary: Who Owns What

| Stage | Accountable | Key Deliverable |
|-------|-------------|-----------------|
| **Discover** | Product Owner | Data Product Canvas |
| **Design** | Product Owner + Architecture | Data Contract v1.0 |
| **Deliver** | Producer | Deployed model + DMFs |
| **Operate** | Platform | Monitoring & 99%+ SLA |
| **Refine** | Product Owner | Data Contract v2.0 |

---

## Key Collaboration Points

| Handoff | From | To | Artifact |
|---------|------|-----|----------|
| Business need → Technical feasibility | Consumer | Architecture | Canvas |
| Canvas → Contract | Product Owner | Producer | YAML contract |
| Contract → Code | Producer | Platform | dbt model + DMFs |
| Monitoring → Feedback | Platform | Product Owner | Usage reports |
| Feedback → Evolution | Consumer | Product Owner | v2.0 requirements |

---

## Lessons Learned

1. **Architecture early** - Design reviews prevented rework and ensured patterns alignment
2. **Governance early** - Involving compliance in Design prevented rework when FCA requirements emerged
3. **Contract as source of truth** - Regenerating code from contract made v2.0 evolution smooth
4. **Platform owns SLAs** - Clear accountability for monitoring reduced incident response time
5. **Consumer feedback loop** - Regular check-ins with retention analysts drove valuable v2.0 features
6. **Producer-Platform handoff** - Clear boundary between build (Producer) and run (Platform)
