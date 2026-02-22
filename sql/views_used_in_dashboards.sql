-- views_used_in_dashboards.sql

   Purpose:
   - Minimal reproducible set of views used to power Tableau dashboards
   - Caps all outputs to dataset max month 


-- ------------------------------------------------------------
-- 1) Cohort retention (by plan tier) capped to dataset max month

DROP VIEW IF EXISTS tableau.cohort_retention_by_plan_tier_rates_capped;

CREATE OR REPLACE VIEW tableau.cohort_retention_by_plan_tier_rates_capped AS
SELECT
  r.cohort_month,
  r.cohort_plan_tier,
  r.months_since,
  r.retained_accounts,
  r.cohort_accounts,
  r.retention_rate
FROM tableau.cohort_retention_by_plan_tier_rates r
CROSS JOIN mart.data_date_bounds b
WHERE r.cohort_month <= date_trunc('month', b.max_date)::date
ORDER BY r.cohort_month, r.cohort_plan_tier, r.months_since;


-- ------------------------------------------------------------
-- 2) Churn exposure by key dimensions (plan, billing, seats bucket)
--    Outputs churn rate (weighted), churned MRR, and MRR exposure

DROP VIEW IF EXISTS mart.churn_exposure_by_dimension;

CREATE OR REPLACE VIEW mart.churn_exposure_by_dimension AS
WITH cutoff AS (
  SELECT cutoff_month
  FROM mart.dataset_cutoff
),
enriched AS (
  SELECT
    f.account_id,
    f.month_start,
    f.was_active_paid_prev_month,
    f.churned_state_this_month,
    f.primary_plan_tier,
    f.primary_billing_frequency,
    f.primary_seats,
    f.total_mrr,
    LAG(f.total_mrr) OVER (PARTITION BY f.account_id ORDER BY f.month_start) AS mrr_prev_month,
    LAG(f.primary_plan_tier) OVER (PARTITION BY f.account_id ORDER BY f.month_start) AS plan_prev,
    LAG(f.primary_billing_frequency) OVER (PARTITION BY f.account_id ORDER BY f.month_start) AS billing_prev,
    LAG(f.primary_seats) OVER (PARTITION BY f.account_id ORDER BY f.month_start) AS seats_prev
  FROM mart.account_month_facts f
  CROSS JOIN cutoff c
  WHERE f.month_start <= c.cutoff_month
),
segmented AS (
  SELECT
    e.month_start,
    e.account_id,
    e.was_active_paid_prev_month,
    e.churned_state_this_month,
    COALESCE(e.mrr_prev_month, e.total_mrr, 0::numeric) AS mrr_prev_or_current,
    COALESCE(e.plan_prev, e.primary_plan_tier, 'UNKNOWN') AS plan_dim,
    COALESCE(e.billing_prev, e.primary_billing_frequency, 'UNKNOWN') AS billing_dim,
    COALESCE(e.seats_prev, e.primary_seats, 0) AS seats_dim
  FROM enriched e
)
SELECT
  month_start,
  dimension_name,
  dimension_value,
  COUNT(*) FILTER (WHERE was_active_paid_prev_month = true) AS base_paid_prev_month,
  SUM(churned_state_this_month) AS churned_accounts,
  SUM(churned_state_this_month)::numeric
    / NULLIF(COUNT(*) FILTER (WHERE was_active_paid_prev_month = true), 0)::numeric AS logo_churn_rate,
  SUM(
    CASE
      WHEN churned_state_this_month = 1 AND was_active_paid_prev_month = true THEN mrr_prev_or_current
      ELSE 0::numeric
    END
  ) AS churned_mrr_exposed,
  SUM(
    CASE
      WHEN was_active_paid_prev_month = true THEN mrr_prev_or_current
      ELSE 0::numeric
    END
  ) AS total_mrr_exposed
FROM (
  SELECT
    s.month_start,
    s.account_id,
    s.was_active_paid_prev_month,
    s.churned_state_this_month,
    s.mrr_prev_or_current,
    'plan_tier'::text AS dimension_name,
    s.plan_dim::text AS dimension_value
  FROM segmented s

  UNION ALL

  SELECT
    s.month_start,
    s.account_id,
    s.was_active_paid_prev_month,
    s.churned_state_this_month,
    s.mrr_prev_or_current,
    'billing_frequency'::text AS dimension_name,
    s.billing_dim::text AS dimension_value
  FROM segmented s

  UNION ALL

  SELECT
    s.month_start,
    s.account_id,
    s.was_active_paid_prev_month,
    s.churned_state_this_month,
    s.mrr_prev_or_current,
    'seats_bucket'::text AS dimension_name,
    CASE
      WHEN s.seats_dim BETWEEN 1 AND 5 THEN '1-5'
      WHEN s.seats_dim BETWEEN 6 AND 20 THEN '6-20'
      WHEN s.seats_dim BETWEEN 21 AND 50 THEN '21-50'
      WHEN s.seats_dim >= 51 THEN '51+'
      ELSE '0/UNKNOWN'
    END AS dimension_value
  FROM segmented s
) u
GROUP BY month_start, dimension_name, dimension_value
ORDER BY
  month_start,
  dimension_name,
  SUM(CASE WHEN was_active_paid_prev_month = true THEN mrr_prev_or_current ELSE 0::numeric END) DESC;


-- ------------------------------------------------------------
-- 3) Risk scoring (capped) used in Risk Monitor dashboard

DROP VIEW IF EXISTS tableau.churn_risk_scoring_capped;

CREATE OR REPLACE VIEW tableau.churn_risk_scoring_capped AS
SELECT
  r.account_id,
  r.month_start,
  r.churned_state_this_month,
  r.risk_score,
  r.risk_band,
  r.reasons
FROM tableau.churn_risk_scoring r
CROSS JOIN mart.data_date_bounds b
WHERE r.month_start <= date_trunc('month', b.max_date)::date
ORDER BY r.month_start, r.risk_band, r.risk_score DESC;


-- ------------------------------------------------------------
-- 4) Monthly churn + churned MRR trend (exec KPI backbone)

DROP VIEW IF EXISTS mart.churn_summary_monthly;

CREATE OR REPLACE VIEW mart.churn_summary_monthly AS
WITH cutoff AS (
  SELECT cutoff_month
  FROM mart.dataset_cutoff
),
enriched AS (
  SELECT
    f.account_id,
    f.month_start,
    f.was_active_paid_prev_month,
    f.churned_state_this_month,
    f.total_mrr,
    LAG(f.total_mrr) OVER (PARTITION BY f.account_id ORDER BY f.month_start) AS mrr_prev_month
  FROM mart.account_month_facts f
  CROSS JOIN cutoff c
  WHERE f.month_start <= c.cutoff_month
)
SELECT
  month_start,
  COUNT(*) FILTER (WHERE was_active_paid_prev_month = true) AS base_paid_prev_month,
  SUM(churned_state_this_month) AS churned_accounts,
  SUM(churned_state_this_month)::numeric
    / NULLIF(COUNT(*) FILTER (WHERE was_active_paid_prev_month = true), 0)::numeric AS logo_churn_rate,
  SUM(
    CASE
      WHEN churned_state_this_month = 1 AND was_active_paid_prev_month = true
        THEN COALESCE(mrr_prev_month, total_mrr, 0::numeric)
      ELSE 0::numeric
    END
  ) AS churned_mrr
FROM enriched
GROUP BY month_start
ORDER BY month_start;
