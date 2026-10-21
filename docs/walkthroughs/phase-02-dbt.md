# Phase 2 — dbt models, tests, docs

## Run

```powershell
cd dbt\streampulse
dbt build --target bigquery          # builds every model and runs every test, in dependency order
dbt docs generate --target bigquery
dbt docs serve                       # browse lineage + column docs at localhost:8080
cd ..\..
```
Then paste the output of: `select * from dbt_dev_marts.mart_data_quality` (gives the real data-quality counts).

## Model map

| Layer | Models | Materialised |
|---|---|---|
| staging | `stg_kkbox__members`, `__transactions`, `__churn_labels`, `__user_logs`, `__log_sample_frame` | views |
| intermediate | `int_transactions__deduped`, `int_subscription_periods`, `int_month_spine`, `int_member_months` | views |
| marts/core | `fct_subscriptions`, `dim_members`, `fct_daily_activity` | tables |
| marts/analytics | KPIs, cohorts, segments, LTV, value at risk, features, daily revenue, data quality | tables |

## Key code 1 — removing duplicates (`int_transactions__deduped`)

```sql
row_number() over (
    partition by member_id, payment_method_id, plan_days, list_price_ntd, amount_paid_ntd,
                 is_auto_renew, is_cancel, transaction_date, expire_date
    order by source_file
) as duplicate_rank
...
where duplicate_rank = 1
```

| Line | What it does | Why |
|---|---|---|
| `row_number() over (…)` | numbers rows 1, 2, 3 inside each group | a window function: it keeps every row (unlike GROUP BY) and adds a column |
| `partition by <every business column>` | a group = rows identical on all of them | identical rows = the same transaction appearing in both v1 and v2 files |
| `order by source_file` | decides which copy is #1 | deterministic: prefer the original file |
| `where duplicate_rank = 1` | keeps one copy | the count removed is reported in `mart_data_quality` |
| flags `is_expire_before_txn`, `is_expire_too_far` | mark impossible dates | flag, don't silently drop — the report counts them |

## Key code 2 — subscription periods that respect cancellations (`int_subscription_periods`)

```sql
sum(case when is_cancel then 0 else 1 end) over (
    partition by member_id
    order by transaction_date, is_cancel, expire_date, transaction_key
    rows between unbounded preceding and current row
) as period_number
```

| Line | What it does | Why |
|---|---|---|
| `sum(case … 0 else 1 end)` | +1 for each purchase/renewal, +0 for a cancel | a running count |
| `over (partition by member_id …)` | restarts the count for every member | each member has their own timeline |
| `order by transaction_date, is_cancel, …` | time order; on the same day, purchase before cancel | `false < true`, so a same-day cancel attaches to that day's purchase |
| `rows between unbounded preceding and current row` | strictly row-by-row running total | the default (RANGE) would treat tied rows as one and give them the same number |
| result | a cancel row inherits the number of the period it cancels | then `min(expire_date)` of cancels per period = the new, earlier end date |

Example: purchase 1 Jan (→1), renewal 31 Jan (→2), cancel 10 Feb (stays 2) → period 2 ends at the cancel's expiry.

## Key code 3 — churned or renewed? (`fct_subscriptions`)

```sql
lead(start_date) over (partition by member_id order by start_date, period_number) as next_period_start_date
...
case
    when end_date + 30 > data_end            then null   -- can't know yet
    when next_period_start_date is null      then true   -- never came back
    when next_period_start_date > end_date + 30 then true -- came back too late
    else false
end as is_churned
```

| Part | What it does | Why |
|---|---|---|
| `lead(start_date)` | the member's next period start, on the same row | compare "this period's end" with "next start" without a self-join |
| `lag(effective_end_date)` | previous period's end | detects reactivations (gap > 30 days) |
| first `when` → NULL | 30-day window runs past 31 Mar 2017 | unknown ≠ retained; counting it as retained would understate churn |
| 30 days | KKBox's own churn definition | same rule as the labels, so numbers are comparable |

## Tests (all run by `dbt build`)

| Test | On | Catches |
|---|---|---|
| `unique`, `not_null` | every primary key | duplicate or missing ids → double counting |
| `relationships` | facts → `dim_members` | orphan rows (why `dim_members` is built from the union of all ids) |
| `accepted_values` | gender, plan buckets, dimensions, source_file | unexpected categories from upstream changes |
| `assert_effective_end_not_before_start` | periods | broken cancel logic |
| `assert_no_feature_after_cutoff` | model features | **data leakage** |
| `assert_label_population_complete` | features vs labels | members silently dropped by a join |
| `assert_retention_rate_between_0_and_1` | cohorts | double-counting in the cohort join |

## ✅ Checklist
- [ ] `dbt build --target bigquery` → `ERROR=0`
- [ ] If a test fails, read it before "fixing" it — paste the failing test name in chat
- [ ] `mart_data_quality` output pasted (feeds the README and a resume bullet)
- [ ] Storage still under 10 GB (BigQuery console → dataset → Storage info)
- [ ] `dbt docs serve` lineage graph screenshot saved to `docs/` for the README

## 🎤 Interview questions
| Q | Answer |
|---|---|
| Why staging → intermediate → marts? | "Staging only cleans and renames, so every source quirk is fixed in one place. Intermediate holds reusable logic like subscription periods. Marts are what people query, with documented grain and tests. If the source changes, I fix one staging model, not ten queries." |
| How did you handle cancellations? | "KKBox logs a cancel as a separate row that shortens the membership. I used a running count of purchases as a period number, so each cancel inherits the period it belongs to, then used the earliest cancel expiry as the period's real end." |
| What does a dbt test give you that checking manually doesn't? | "It runs on every build. A relationships test caught that some paying users aren't in the members file — so I built `dim_members` from every id instead of losing them. And the leakage test fails the build if a feature ever uses post-cutoff data." |
