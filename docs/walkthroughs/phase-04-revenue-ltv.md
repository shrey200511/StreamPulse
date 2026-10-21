# Phase 4 — Revenue & LTV

## Run
`notebooks/04_revenue_ltv.ipynb` → Run All → paste `results/phase04_revenue_ltv.json`.

## Three ways to value a customer, and when each is honest

| Measure | Formula | Honest when | Weakness |
|---|---|---|---|
| ARPU | monthly revenue ÷ month-end actives | always (a rate, not a lifetime) | says nothing about how long people stay |
| **Observed 12-month value** | money actually paid in a new customer's first 12 months | the cohort has 12 months of data | ignores value after month 12 |
| Formula LTV | monthly price ÷ monthly churn | churn is roughly constant | real churn is front-loaded, so this can overstate LTV |

The observed measure is the headline; formula LTV is shown with the label **ASSUMPTION**.

## Key SQL — observed 12-month value (`mart_ltv_by_segment`)

```sql
customers as (
    select * from dim_members
    where is_new_customer
      and cohort_month <= add_months(last_data_month, -12)      -- right-censoring guard
),
first_year as (
    select c.member_id, sum(s.amount_paid_ntd) as paid_first_12m_ntd
    from customers c
    join fct_subscriptions s
      on c.member_id = s.member_id and s.start_date < add_months(c.cohort_month, 12)
    group by c.member_id
)
...
rank() over (partition by dimension order by avg_value_12m_ntd desc) as value_rank
```

| Part | What it does | Why |
|---|---|---|
| `cohort_month <= last month − 12` | only cohorts with a full year observed | **right-censoring**: young cohorts would look cheap only because their future isn't in the data |
| `start_date < cohort_month + 12 months` | payments in the first year only | same window for everyone → comparable |
| `sum(amount_paid_ntd)` | cash actually paid | real money, not list price |
| `left join` + `coalesce(…, 0)` (in `base`) | customers with no first-year payment count as 0 | dropping them would inflate the average |
| `rank() over (partition by dimension …)` | ranks segments within each dimension | window function: ranking without collapsing rows |

## Key SQL — revenue lost (`mart_value_at_risk`)

| Column | Meaning | Why |
|---|---|---|
| `monthly_revenue_lost_ntd` | Σ monthly-equivalent price of members who churned | money that stops next month — observed, not modelled |
| `annualised_…_assumption` | × 12 | **assumes** they'd otherwise have stayed a year; labelled everywhere |
| `share_of_revenue_lost` = x / `sum(x) over ()` | segment share of total loss | `over ()` = window over the whole table → total on every row, no subquery |
| `value_at_risk_rank` | `rank() over (order by loss desc)` | where to act first |

## ✅ Checklist
- [ ] `results/phase04_revenue_ltv.json` created
- [ ] ARPU trend explained (price change? plan mix? discounts?) — check `paid_or_renewal_txns` and plan mix before guessing
- [ ] Top 3 segments by revenue lost written down — these become memo finding #2
- [ ] Formula LTV vs observed 12-month value compared; you can explain the gap

## 🎤 Interview questions
| Q | Answer |
|---|---|
| How did you calculate LTV? | "Two ways. Observed: what new customers actually paid in their first 12 months, using only cohorts with a full year of data. Formula: monthly price over monthly churn, which assumes constant churn — I show it as an assumption because retention curves show churn is highest early." |
| What is right-censoring? | "When the outcome hasn't happened yet for recent customers. A cohort from last month has paid for one month — not because it's worth less, but because we haven't seen the rest. So I only used cohorts with 12 months observed." |
| How did you size the cost of churn? | "Monthly-equivalent price of members who actually churned in the label month — observed. The annual figure multiplies by 12 and I label it as an assumption, because some would have churned later anyway." |
