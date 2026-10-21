{% docs __overview__ %}
# StreamPulse — KKBox subscription churn

**Question:** who churns, when, why, what does it cost, and what should the business do?

Layers:

| Layer | Materialised as | Purpose |
|---|---|---|
| `staging` | views | 1:1 with raw tables: rename, type, clean junk values. No joins. |
| `intermediate` | views | Reusable logic: dedupe, subscription periods (cancel-aware), month spine, member-months. |
| `marts/core` | tables | `fct_subscriptions`, `dim_members`, `fct_daily_activity`. |
| `marts/analytics` | tables | Retention, churn segments, KPIs, LTV, value at risk, model features, data quality. |

**Sampling:** `user_logs` is a deterministic 10% (default) USER sample. `fct_daily_activity` and every
listening feature cover sampled users only. members / transactions / labels are complete.

**Churn definition (KKBox):** no new valid subscription within 30 days after the membership expires.
{% enddocs %}
