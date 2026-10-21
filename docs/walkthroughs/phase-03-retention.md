# Phase 3 — Retention & cohorts

## Run
```powershell
$env:STREAMPULSE_TARGET="bigquery"; $env:GCP_PROJECT="YOUR_PROJECT_ID"
jupyter lab notebooks/03_retention_cohorts.ipynb      # Run All
```
Paste `results/phase03_retention.json` into chat.

## Key SQL — cohort retention (`mart_cohort_retention`)

```sql
with cohort_members as (                                 -- CTE 1
    select member_id, cohort_month, first_plan_group
    from dim_members where is_new_customer
),
cohort_sizes as (                                        -- CTE 2
    select cohort_month, first_plan_group, count(*) as cohort_size
    from cohort_members group by 1, 2
),
activity as (                                            -- CTE 3
    select c.cohort_month, c.first_plan_group,
           datediff(month, c.cohort_month, mm.month_start) as months_since_signup,
           count(*) as active_users
    from cohort_members c
    join int_member_months mm on c.member_id = mm.member_id and mm.month_start >= c.cohort_month
    group by 1, 2, 3
),
grid as (                                                -- CTE 4
    select cs.*, s.month_start, datediff(month, cs.cohort_month, s.month_start) as months_since_signup
    from cohort_sizes cs join int_month_spine s on s.month_start >= cs.cohort_month
)
select g.*, coalesce(a.active_users, 0) as active_users,
       active_users / cohort_size as retention_rate,
       active_users / first_value(active_users) over (partition by cohort_month, first_plan_group
                                                      order by months_since_signup) as retention_vs_month0
from grid g left join activity a using (cohort_month, first_plan_group, months_since_signup)
```

| Part | What it does | Why |
|---|---|---|
| CTE 1 `is_new_customer` | keeps members registered on/after 2015-01-01 | **left-censoring**: earlier members may have paid before our data starts, so their "first" month isn't real |
| CTE 2 `cohort_size` | members per signup month × first plan | the denominator — counted from members, not from activity, so people who never stay active still count |
| CTE 3 `int_member_months` join | every month each member was active at month-end | numerator per month-since-signup |
| `datediff(month, …)` | 0 = signup month, 1 = next … | aligns cohorts so you compare "month 3" across cohorts |
| CTE 4 `grid` × month spine | every cohort × every later month | a month with 0 actives still appears (a plain join would drop it and make retention look better) |
| `left join` + `coalesce(…, 0)` | missing = 0 actives | same reason |
| `first_value(…) over (… order by months_since_signup)` | month-0 actives on every row | window function; gives a survival curve that starts at 100% |
| counts stored, not just rates | Tableau sums counts across plan groups | averaging rates across groups of different sizes is wrong |

CTEs vs subqueries: each CTE is one named step you can test on its own; the query reads top-to-bottom like the reasoning.

## In the notebook

| Step | Why |
|---|---|
| Sum counts before dividing for the heatmap | weighted correctly; never average rates |
| Average curve uses only cohorts with 12 months observed | otherwise later months mix in only older cohorts (mix shift) |
| Renewal churn excludes warm-up and unobservable months | first 6 months undercount; last month's 30-day window isn't complete |
| Wilson 95% CIs on segment churn | small segments are noisy; Wilson works well near 0% |
| `MIN_SEGMENT_USERS = 1000` before quoting a segment | avoids headlines from tiny groups |
| Two-proportion z-test on auto-renew | is the gap bigger than chance? (still association, not cause) |

## ✅ Checklist
- [ ] Notebook ran top to bottom with `target=bigquery`, banner says REAL (no SYNTHETIC banner)
- [ ] `results/phase03_retention.json` created
- [ ] Month-0 retention is at or near 100% for most cohorts (if not, ask why — e.g. short trial plans)
- [ ] You can say in one sentence where the retention curve flattens
- [ ] Figures in `results/figures/p03_*.png` look sensible

## 🎤 Interview questions
| Q | Answer |
|---|---|
| What is a cohort and why use one? | "A group defined by when they started — signup month here. Comparing cohorts at the same age separates 'are we getting worse at keeping people' from 'we just have more new people right now'." |
| Why only members registered from 2015? | "Left-censoring. The data starts in 2015, so for someone who registered in 2013 their first observed payment isn't their first payment. Putting them in a 2015 cohort would make that cohort look artificially loyal." |
| How did you decide a segment difference was real? | "Wilson confidence intervals for each rate, a minimum segment size before I'd quote it, and a two-proportion z-test for the key comparison. I also say it's an association — auto-renew users differ in other ways." |
