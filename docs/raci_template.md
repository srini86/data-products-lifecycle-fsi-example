# Data Product Lifecycle - RACI Matrix

> A practical RACI showing team accountability across the five lifecycle phases, illustrated with the **Retail Customer Churn Risk** data product.

---

## Legend

| Code | Role | Description |
|------|------|-------------|
| **R** | Responsible | Performs the work |
| **A** | Accountable | Owns the outcome (only one per activity) |
| **C** | Consulted | Provides input before decisions |
| **I** | Informed | Kept updated on progress |

---

## Roles

| Role | Focus | Example |
|------|-------|---------|
| **Product Owner** | Business outcomes, prioritization, sign-off | Alex Morgan, Retail Analytics |
| **Architecture** | Standards, patterns, technical design | Jamie Rivera, Enterprise Architecture |
| **Producer** | Builds and delivers the data product | Jordan Lee, Data Engineering |
| **Platform** | Infrastructure, monitoring, SLAs | Sam Chen, DataOps |
| **Governance** | Quality rules, masking, compliance | Taylor Smith, Risk & Compliance |
| **Consumer** | Uses the data product, provides feedback | Casey Brown, Business Intelligence |

---

## Data Product RACI — Summary View

| Phase | Activity | Product Owner | Architecture | Producer | Platform | Governance | Consumer |
|-------|----------|:-------------:|:------------:|:--------:|:--------:|:----------:|:--------:|
| **DISCOVER** | Identify business need | **A** | I | I | I | C | R |
| | Assess feasibility & sources | C | **A** | R | C | I | I |
| | Create Data Product Canvas | **A** | C | C | I | C | R |
| **DESIGN** | Define schema & transformations | **A** | R | C | I | C | C |
| | Specify SLAs & quality rules | C | C | C | R | **A** | I |
| | Define access & masking | C | C | I | I | **A** | I |
| | Review & sign-off contract | **A** | R | C | C | R | C |
| **DELIVER** | Build data product (dbt/SQL) | I | C | **A** | C | I | I |
| | Implement quality & masking | I | I | R | C | **A** | I |
| | Deploy to production | I | C | R | **A** | C | I |
| | Publish to marketplace | **A** | I | R | C | C | I |
| **OPERATE** | Monitor SLAs & freshness | I | I | C | **A** | I | I |
| | Respond to alerts & incidents | C | I | R | **A** | C | I |
| | Verify compliance & masking | I | I | I | C | **A** | I |
| | Track usage & adoption | **A** | I | I | R | I | C |
| **REFINE** | Gather feedback & requirements | **A** | I | I | I | C | R |
| | Evolve schema & contract | **A** | R | C | I | C | C |
| | Regenerate & redeploy | I | C | **A** | R | C | I |
| | Communicate changes | **A** | I | C | I | I | R |

---

## Phase-by-Phase Detail

### DISCOVER: Identifying the Opportunity

| Activity | PO | Arch | Producer | Platform | Governance | Consumer |
|----------|:--:|:----:|:--------:|:--------:|:----------:|:--------:|
| Identify churn prediction need | **A** | I | I | I | C | R |
| Define success KPIs (reduce churn by 15%) | **A** | I | C | I | C | R |
| Assess source data availability | C | C | **A** | C | I | I |
| Evaluate technical feasibility | C | **A** | R | C | I | I |
| Create Data Product Canvas | **A** | C | C | I | C | R |
| Prioritize on roadmap | **A** | C | I | I | C | C |

**Deliverable:** Data Product Canvas (`01_discover/data_product_canvas.yaml`)

---

### DESIGN: Defining the Contract

| Activity | PO | Arch | Producer | Platform | Governance | Consumer |
|----------|:--:|:----:|:--------:|:--------:|:----------:|:--------:|
| Define output columns (schema) | **A** | C | R | C | C | C |
| Design transformation patterns | C | **A** | R | C | I | I |
| Specify SLA (daily refresh by 6 AM UTC) | **A** | C | C | R | I | I |
| Define quality rules (no nulls, valid ranges) | C | C | R | I | **A** | C |
| Specify masking (customer_name → PII) | C | C | C | I | **A** | I |
| Document source lineage (5 tables) | I | C | R | C | **A** | I |
| Review & sign-off contract | **A** | R | C | C | R | C |

**Deliverable:** Data Contract v1.0 (`02_design/churn_risk_data_contract.yaml`)

---

### DELIVER: Building the Product

| Activity | PO | Arch | Producer | Platform | Governance | Consumer |
|----------|:--:|:----:|:--------:|:--------:|:----------:|:--------:|
| Generate dbt model via Streamlit app | I | C | **A** | C | I | I |
| Build transformations (risk scoring) | I | C | **A** | C | I | I |
| Code review against standards | I | **A** | R | C | I | I |
| Implement masking policies | I | C | R | C | **A** | I |
| Set up DMFs (NULL_COUNT, FRESHNESS) | I | C | R | **A** | C | I |
| Create semantic view for Cortex Analyst | C | C | **A** | C | I | C |
| Publish to internal marketplace | **A** | I | R | C | C | I |
| Deploy to production | I | C | R | **A** | C | I |

**Deliverables:** 
- dbt model deployed (`retail_customer_churn_risk.sql`)
- DMFs configured (`03_deliver/02_data_quality_dmf.sql`)
- Marketplace listing live

---

### OPERATE: Running the Product

| Activity | PO | Arch | Producer | Platform | Governance | Consumer |
|----------|:--:|:----:|:--------:|:--------:|:----------:|:--------:|
| Monitor 24-hour freshness SLA | I | I | C | **A** | I | I |
| Monitor quality expectations | I | I | C | **A** | R | I |
| Respond to SLA breach alerts | C | I | R | **A** | C | I |
| Track usage & adoption metrics | **A** | I | I | R | I | C |
| Verify masking compliance | I | I | I | C | **A** | I |
| Optimize query performance | I | C | R | **A** | I | I |
| Monthly KPI report to business | **A** | I | C | I | I | R |

**Deliverables:** 
- Monitoring dashboard (`04_operate/monitoring_observability.sql`)
- 99%+ SLA compliance

---

### REFINE: Evolving to v2.0

| Activity | PO | Arch | Producer | Platform | Governance | Consumer |
|----------|:--:|:----:|:--------:|:--------:|:----------:|:--------:|
| Gather feedback (need CLV, confidence) | **A** | I | I | I | I | R |
| Compliance request (FCA vulnerability) | C | I | I | I | **A** | I |
| Propose new columns for v2.0 | **A** | C | C | I | C | R |
| Review schema evolution approach | C | **A** | R | C | C | I |
| Update data contract to v2.0 | **A** | C | R | I | C | C |
| Regenerate dbt model from contract | I | C | **A** | R | C | I |
| Archive v1.0 snapshot for audit | I | I | R | **A** | C | I |
| Add DMFs for new columns | I | I | R | **A** | C | I |
| Communicate changes to consumers | **A** | I | C | I | I | R |

**Deliverable:** Data Contract v2.0 (`05_refine/churn_risk_data_contract_v2.yaml`)

---

## Accountability Summary

| Phase | Primary Accountable | Key Deliverable |
|-------|---------------------|-----------------|
| **Discover** | Product Owner | Data Product Canvas |
| **Design** | Product Owner + Architecture | Data Contract |
| **Deliver** | Producer | Deployed Product + DMFs |
| **Operate** | Platform | SLA Compliance |
| **Refine** | Product Owner | Updated Contract |

---

## Key Handoffs

| Handoff | From | To | Artifact |
|---------|------|-----|----------|
| Business need → Feasibility | Consumer | Architecture | Canvas |
| Canvas → Contract | Product Owner | Producer | YAML contract |
| Contract → Code | Producer | Platform | dbt model + DMFs |
| Monitoring → Feedback | Platform | Product Owner | Usage reports |
| Feedback → Evolution | Consumer | Product Owner | v2.0 requirements |

---

## Lessons Learned

1. **Architecture early** — Design reviews prevented rework and ensured patterns alignment
2. **Governance early** — Involving compliance in Design prevented rework when FCA requirements emerged
3. **Contract as source of truth** — Regenerating code from contract made v2.0 evolution smooth
4. **Platform owns SLAs** — Clear accountability for monitoring reduced incident response time
5. **Single Accountable per task** — Multiple A's lead to diffusion of responsibility
6. **Consumer feedback loop** — Regular check-ins with retention analysts drove valuable v2.0 features
7. **Producer-Platform handoff** — Clear boundary between build (Producer) and run (Platform)
8. **Make RACI visible** — Reference it in meetings and kickoffs, not just store in a document

---

*Based on RACI best practices from product management and data mesh literature.*
