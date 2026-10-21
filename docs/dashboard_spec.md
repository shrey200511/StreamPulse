# Tableau Public dashboard spec

Data: the CSVs in `dashboard/data/` (from `scripts/export_for_tableau.py`). Tableau Public can't keep a
live BigQuery connection in a published workbook, so it uses these extracts; they're aggregated, so no
member-level data is published.

Global style: one accent colour for "bad" (churn, loss) and one neutral; NTD formatted `#,##0`; every
sheet subtitle states the population ("All subscribers", "New customers 2015–2016", "Label population: Mar 2017 expiries").

## View 1 — Executive KPIs (`monthly_kpis.csv`, `subscriber_forecast.csv`)

| Element | Field / calculation |
|---|---|
| KPI tiles (latest full month) | Active subscribers · Revenue · ARPU · Renewal churn (last observable month) |
| Line: active subscribers + next-quarter forecast band | `active_subscribers`; forecast + `low_95`/`high_95` from subscriber_forecast.csv |
| Bars: monthly revenue, line: ARPU | `revenue_ntd`, `arpu_ntd` |
| Filter | Exclude warm-up months: `[is_warmup_month] = FALSE` (default on, with a note explaining why) |

## View 2 — Retention & cohorts (`cohort_retention.csv`)

| Element | Field / calculation |
|---|---|
| Heatmap: cohort × months since signup | Colour = `SUM([active_users]) / SUM([cohort_size])` — calculated field `Retention`. Never AVG the rate. |
| Line: retention curves by first plan group | Same `Retention` calc, colour = `first_plan_group` |
| Filter | `first_plan_group` (multi-select), `months_since_signup ≤ 12` |
| Note | "New customers only (registered ≥ 2015-01-01)" |

## View 3 — Churn drivers & revenue at risk (`churn_by_segment.csv`, `value_at_risk.csv`, `churn_drivers.csv`)

| Element | Field / calculation |
|---|---|
| Bar: churn rate by segment, reference line = overall | `churn_rate`; parameter to pick `dimension` |
| Bar: top 10 segments by monthly revenue lost | `monthly_revenue_lost_ntd`, label `share_of_revenue_lost` |
| Bar: churn drivers (Model A) | `ame_pp` (percentage points), only `significant_5pct = TRUE` |
| Tile | Monthly revenue lost; annualised version labelled "ASSUMPTION: churners would otherwise stay 12 months" |

## Publish checklist
- [ ] Every sheet has a title that states the takeaway, not the metric ("Auto-renew-off members churn N× more")
- [ ] Sampled numbers labelled "10% user sample"
- [ ] Tooltips show counts, not just rates
- [ ] Works at 1200 px wide; tested on phone layout
- [ ] Link added to the README
