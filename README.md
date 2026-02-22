# SaaS Retention, Churn Drivers & Early Warning System (RavenStack)

## Business Problem
RavenStack (synthetic SaaS) wants to **reduce churn and improve retention**. This project builds an analytics workflow to:
1) quantify churn + revenue impact,
2) identify where churn is concentrated (segments),
3) validate a rules-based early warning system, and
4) track retention through cohort analysis.

**Tableau Public Workbook:** https://public.tableau.com/app/profile/aarya.bhivsanee/vizzes 

**Dataset:** RavenStack / Rivalytics “SaaS Subscription & Churn Analytics” 
(https://www.kaggle.com/datasets/rivalytics/saas-subscription-and-churn-analytics-dataset)


## What I Built (End-to-End)
### 1) Metric Layer (PostgreSQL)
- Defined **logo churn** using a state transition (paid → not paid) at the account-month grain.
- Built revenue impact metrics including **churned MRR** and **MRR exposure** by segment.
- Produced a strict **paid cohort retention** dataset and milestone checkpoints (M1/M3/M6).

### 2) Churn Concentration (Business Segmentation)
Created a reusable segmentation output to answer: *“Where is churn hurting the business most?”*
- Segment dimensions: **plan tier**, **billing frequency**, **seat size buckets**
- Outputs: churn rate (weighted), churned accounts, **churned MRR**, total MRR exposed

### 3) Early Warning System (Rules-Based)
Built a non-ML risk scoring system that flags accounts using behavioral/support signals (e.g., usage drop, errors, support friction) and outputs:
- **risk_score**, **risk_band (LOW/MED/HIGH)**, and **reason codes**
- Validation: HIGH risk band shows materially higher churn than LOW

### 4) Tableau Dashboards (3)
1) **Executive Overview + Revenue Impact**
   - Latest month KPIs + churn trend + MRR trend + churned MRR trend
   - Segment explorer for churned MRR exposure
2) **Risk Monitor (Early Warning)**
   - Risk mix trend, top at-risk accounts, top reason combinations
   - Validation chart: churn rate by risk band
3) **Retention & Cohorts**
   - Cohort retention curve + cohort heatmap
   - Retention milestone KPIs (M1/M3/M6)

---

## Key Results (from dashboards)
- Latest month (Dec 2024) **logo churn rate: 8.02%** (**34 churned / 448 base**)  
- Paid MRR in latest month: **$9.89M**
- Cohort milestones (paid retention):
  - **M1: 90.1%**
  - **M3: 76.5%**
  - **M6: 57.4%**
- Risk model validation (latest month):
  - **HIGH risk churn rate ~50%** vs **LOW risk ~7%** (clear separation)

> Note: The dataset’s observed event window ends in **Dec 2024**; all KPI tables are capped to the dataset cutoff for accurate reporting.

---

## How to Use This Repo
### Repo Structure
- `/sql`
  - `01_cleaning.sql` – cleaned tables + type casting + constraints
  - `02_metric_layer.sql` – account-month facts + KPI tables
  - `03_cohorts.sql` – strict paid cohort retention outputs
  - `04_risk.sql` – churn risk scoring + reasons + validation outputs
- `/dashboard`
  - Tableau Public link + screenshots
- `/memo`
  - 1-page executive memo PDF

## Business Recommendations (Based on Findings)
- Prioritize retention work where **churned MRR is concentrated** (segment explorer).
- Focus on **first 90 days**: large drop from **M1 → M3** indicates activation/onboarding improvements will have outsized impact.
- Operationalize the early warning list: contact **HIGH risk** accounts first and address the top reason codes (usage drop + errors, then support friction).

---
