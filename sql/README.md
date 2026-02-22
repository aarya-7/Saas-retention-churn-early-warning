## SQL (Views used by dashboards)
This repo includes a minimal SQL artifact (not the full build pipeline) that captures the final Postgres views powering the Tableau dashboards:

- `sql/views_used_in_dashboards.sql`
  - `mart.churn_summary_monthly` → churn + churned MRR trend (Executive)
  - `mart.churn_exposure_by_dimension` → segment explorer (plan/billing/seats)
  - `tableau.churn_risk_scoring_capped` → risk monitor + validation
  - `tableau.cohort_retention_by_plan_tier_rates_capped` → cohort retention by plan tier
