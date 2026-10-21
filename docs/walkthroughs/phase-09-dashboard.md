# Phase 9 — Tableau Public dashboard

## Run
```powershell
python scripts/export_for_tableau.py      # writes dashboard/data/*.csv from the real marts
```
Then in Tableau Public (free desktop app): connect → Text file → add every CSV in `dashboard/data/` as separate
data sources (no joins needed; each view uses one or two). Build the three views in
[`docs/dashboard_spec.md`](../dashboard_spec.md), then *File → Save to Tableau Public*. Add the link to the README.

## Calculated fields to create

| Name | Formula | Why |
|---|---|---|
| `Retention` | `SUM([active_users]) / SUM([cohort_size])` | correct weighting across cohorts/plan groups |
| `Churn Rate` | `SUM([churners]) / SUM([users])` | same, for segment views |
| `Revenue (M NTD)` | `SUM([revenue_ntd]) / 1000000` | readable axis |
| `Exclude warm-up` | `NOT [is_warmup_month]` | hides left-censored months by default |
| `Dimension picker` | parameter over `dimension` values; filter `[dimension] = [Dimension picker]` | one chart serves 8 segment dimensions |

## ✅ Checklist
- [ ] CSVs came from the real run (`dashboard/data/`, not `_SYNTHETIC_TEST_ONLY`)
- [ ] Three views built per spec; titles state the takeaway
- [ ] Sampled numbers labelled; assumption numbers labelled
- [ ] Published; link in README; screenshot saved to `dashboard/`

## 🎤 Interview questions
| Q | Answer |
|---|---|
| Why CSV extracts instead of a live BigQuery connection? | "Tableau Public can't keep live database connections in published workbooks. The marts are already aggregated, so extracts are small, contain no member-level data, and are versioned in Git with the code that made them." |
| Why sum counts instead of averaging rates? | "Averaging retention rates gives a 50-person cohort the same weight as a 50,000-person one. Summing actives and cohort sizes, then dividing, weights correctly." |
| Who is each view for? | "Executive KPIs for leadership — trend and forecast. Retention for the growth team — where in the lifecycle people leave. Drivers and revenue at risk for whoever owns retention offers — who to target first." |
