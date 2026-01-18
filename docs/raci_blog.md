# Data Product Lifecycle - RACI Matrix

> A single-view RACI showing team accountability across all five lifecycle phases.

## Roles

| Role | Focus |
|------|-------|
| **Product Owner** | Business outcomes, prioritization, sign-off |
| **Architecture** | Standards, patterns, technical design |
| **Producer** | Builds and delivers the data product |
| **Platform** | Infrastructure, monitoring, SLAs |
| **Governance** | Quality rules, masking, compliance |
| **Consumer** | Uses the data product, provides feedback |

---

## Data Product RACI

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

## Accountability Summary

| Phase | Primary Accountable | Key Deliverable |
|-------|---------------------|-----------------|
| **Discover** | Product Owner | Data Product Canvas |
| **Design** | Product Owner + Architecture | Data Contract |
| **Deliver** | Producer | Deployed Product |
| **Operate** | Platform | SLA Compliance |
| **Refine** | Product Owner | Updated Contract |

---

**Legend:** **R** = Responsible (does the work) · **A** = Accountable (owns outcome) · **C** = Consulted · **I** = Informed
