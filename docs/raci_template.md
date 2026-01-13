# Data Product Lifecycle - RACI Matrix

> A RACI matrix defines **who does what** across the data product lifecycle, ensuring clarity, accountability, and efficient collaboration between teams.

## Legend

| Code | Role | Description |
|------|------|-------------|
| **R** | Responsible | Performs the work |
| **A** | Accountable | Owns the outcome (one per task) |
| **C** | Consulted | Provides input before decisions |
| **I** | Informed | Kept updated on progress |

---

## Key Roles

| Role | Description | Example Titles |
|------|-------------|----------------|
| **Product Owner** | Owns business outcomes and prioritization | Data Product Manager, Business Owner |
| **Data Engineer** | Builds and maintains data pipelines | Analytics Engineer, dbt Developer |
| **Platform Team** | Manages infrastructure and tooling | DataOps, Platform Engineer |
| **Governance** | Ensures compliance and data quality | Data Steward, Compliance Officer |
| **Consumers** | Uses the data product | Analyst, Data Scientist, BI Developer |
| **Stakeholders** | Business sponsors and end users | Retention Manager, Risk Officer |

---

## RACI by Lifecycle Stage

### 1. DISCOVER

| Activity | Product Owner | Data Engineer | Platform Team | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:-------------:|:----------:|:---------:|:------------:|
| Identify business problem | R | I | I | C | C | **A** |
| Define success metrics (KPIs) | R | C | I | C | C | **A** |
| Assess data availability | C | R | C | I | I | I |
| Create Data Product Canvas | **A** | C | I | C | R | C |
| Prioritize against roadmap | **A** | I | I | C | I | C |

### 2. DESIGN

| Activity | Product Owner | Data Engineer | Platform Team | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:-------------:|:----------:|:---------:|:------------:|
| Define data contract (schema, SLAs) | **A** | R | C | C | C | I |
| Specify data quality rules | C | R | I | **A** | C | I |
| Define access controls & masking | C | C | I | **A** | I | I |
| Document lineage requirements | I | R | C | **A** | I | I |
| Review & approve contract | **A** | C | C | R | C | I |

### 3. DELIVER

| Activity | Product Owner | Data Engineer | Platform Team | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:-------------:|:----------:|:---------:|:------------:|
| Generate code from contract | I | **A** | C | I | I | I |
| Build dbt models & transformations | I | **A** | C | I | I | I |
| Implement masking policies | I | R | C | **A** | I | I |
| Set up Data Metric Functions (DMFs) | I | R | **A** | C | I | I |
| Create semantic views | C | **A** | C | I | C | I |
| Publish to internal marketplace | **A** | R | C | C | I | I |
| Deploy to production | I | R | **A** | C | I | I |

### 4. OPERATE

| Activity | Product Owner | Data Engineer | Platform Team | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:-------------:|:----------:|:---------:|:------------:|
| Monitor freshness SLAs | I | C | **A** | I | I | I |
| Monitor data quality expectations | I | C | **A** | R | I | I |
| Respond to alerts & incidents | C | R | **A** | C | I | I |
| Track usage & adoption | **A** | I | R | I | I | C |
| Verify compliance (masking, access) | I | I | C | **A** | I | I |
| Report on KPIs to stakeholders | **A** | C | I | I | C | R |

### 5. REFINE

| Activity | Product Owner | Data Engineer | Platform Team | Governance | Consumers | Stakeholders |
|----------|:-------------:|:-------------:|:-------------:|:----------:|:---------:|:------------:|
| Gather feedback from consumers | **A** | I | I | I | R | C |
| Analyze usage patterns & drift | C | R | **A** | I | I | I |
| Propose enhancements | **A** | C | I | C | R | C |
| Update data contract (new version) | **A** | R | I | C | C | I |
| Regenerate & deploy updated model | I | **A** | R | C | I | I |
| Archive previous version | I | R | **A** | C | I | I |
| Communicate changes to consumers | **A** | C | I | I | R | I |

---

## Summary View

| Stage | Primary Accountable | Key Activities |
|-------|---------------------|----------------|
| **Discover** | Stakeholders / Product Owner | Problem definition, canvas creation |
| **Design** | Product Owner / Governance | Contract specification, quality rules |
| **Deliver** | Data Engineer | Code generation, deployment |
| **Operate** | Platform Team | Monitoring, SLA management |
| **Refine** | Product Owner | Feedback loop, evolution |

---

## Example: Retail Customer Churn Risk

| Stage | Who Led | Key Outcome |
|-------|---------|-------------|
| Discover | Retention Team (Stakeholder) | Identified need for churn prediction |
| Design | Data Product Owner + Governance | Created data contract with 32 columns, SLAs, masking |
| Deliver | Data Engineer | Generated dbt model via Streamlit app, deployed DMFs |
| Operate | Platform Team | Monitored freshness, quality, usage across 3 consumer roles |
| Refine | Product Owner + Compliance | Added CLV, vulnerability indicator (v2.0) based on feedback |

---

## Tips for Implementation

1. **One Accountable per task** - Avoid confusion by having a single owner
2. **Minimize Consulted** - Too many C's slow decisions down
3. **Right-size Informed** - Keep stakeholders in the loop without overwhelming
4. **Review quarterly** - As teams mature, responsibilities may shift
5. **Integrate with contracts** - The data contract should reference who is accountable for each SLA

---

## Related Resources

- [Data Product Canvas](../01_discover/data_product_canvas.html)
- [Data Contract v1.0](../02_design/churn_risk_data_contract.yaml)
- [Data Contract v2.0](../05_refine/churn_risk_data_contract_v2.yaml)
