# Data dictionary

Full, always-current version: `cd dbt/streampulse && dbt docs generate && dbt docs serve`.
Currency: **NTD** (New Taiwan Dollar). Dates: 2015-01-01 → 2017-03-31.

## Raw sources (Kaggle KKBox, WSDM Cup 2018)

| File | Raw table | Rows kept | Key columns |
|---|---|---|---|
| members_v3.csv | `raw.members` | all | msno, city, bd (age), gender, registered_via, registration_init_time |
| transactions.csv + transactions_v2.csv | `raw.transactions` | all (overlap removed in dbt) | msno, payment_method_id, payment_plan_days, plan_list_price, actual_amount_paid, is_auto_renew, transaction_date, membership_expire_date, is_cancel |
| train_v2.csv | `raw.churn_labels` | all | msno, is_churn (memberships expiring Mar 2017; churn = no new subscription within 30 days) |
| user_logs.csv + user_logs_v2.csv | `raw.user_logs` | ⚠️ user sample | msno, date, num_25/50/75/985/100 (songs played to <25%…100%), num_unq, total_secs |
| — | `raw.log_sample_frame` | all users | msno, sample_bucket, in_log_sample |

## fct_subscriptions — one row per subscription period

| Column | Meaning |
|---|---|
| subscription_id | md5 key of the transaction that started the period |
| member_id | user id (msno) |
| period_number | 1, 2, 3 … per member in time order |
| start_date / original_expire_date | from the transaction |
| effective_end_date | expiry, or the earlier date set by a cancellation during the period |
| plan_days, plan_length_bucket | plan length and its bucket |
| list_price_ntd, amount_paid_ntd, discount_ntd | prices |
| monthly_price_ntd | amount paid × 30 / plan_days |
| is_auto_renew, payment_method_id, is_discounted, is_free | plan attributes |
| was_cancelled, cancel_date | cancellation during this period |
| is_reactivation | started more than 30 days after the previous period ended |
| next_period_start_date | from LEAD() |
| is_churn_observable | the 30 days after the end are inside the data |
| is_churned | no new period within 30 days of the end (NULL if not observable) |

## dim_members — one row per member

| Column | Meaning |
|---|---|
| age, age_bucket | age if 10–80, else NULL / 'unknown' |
| gender, city_id, registration_channel_id, registration_date | profile |
| is_in_members_table | false for paying users missing from members_v3 |
| first_period_start_date, cohort_month | first observed subscription |
| is_new_customer | registered ≥ 2015-01-01 → first observed period is the true first (used for cohorts/LTV) |
| first_plan_group | Free/promo · Short plan · Monthly auto-renew · Monthly manual · Multi-month |
| n_periods, lifetime_paid_ntd, n_cancelled_periods | history totals |
| is_in_label_population, is_churn_label | KKBox label |
| in_log_sample | listening logs available |

## fct_daily_activity — one row per member per day ⚠️ sampled users only

| Column | Meaning |
|---|---|
| plays_total | all plays that day |
| plays_mostly_complete | plays listened to ≥ 75% |
| completion_rate | plays_mostly_complete / plays_total |
| early_skip_rate | share skipped before 25% |
| unique_songs, listen_secs, listen_minutes | engagement; seconds outside 0–86,400 set to NULL |
| has_invalid_secs | raw seconds value was impossible |

## mart_churn_features — one row per labelled member (inputs to Phase 5)

All features use data **on or before 2017-02-28** (`feature_cutoff_date`).

| Group | Columns |
|---|---|
| Plan at cutoff | last_plan_days, last_plan_length_bucket, last_amount_paid_ntd, last_monthly_price_ntd, monthly_price_bucket, last_is_discounted, last_is_free, last_is_auto_renew, last_payment_method_id, last_period_cancelled_before_cutoff, days_to_expiry_at_cutoff |
| History | n_periods_before_cutoff, n_cancels_before_cutoff, n_reactivations, n_payment_methods, tenure_days, paid_to_date_ntd |
| Profile | age, age_bucket, gender, city_id, registration_channel_id, days_since_registration |
| Listening ⚠️ sample | active_days_30d, listen_minutes_30d, plays_30d, completion_rate_30d, unique_songs_30d, active_days_prev_30d, listen_minutes_prev_30d, active_days_change, days_since_last_listen (NULL outside the sample) |

## Analytics marts

| Model | Grain | Main columns |
|---|---|---|
| mart_monthly_kpis | month | active_subscribers, new_customers, revenue_ntd, arpu_ntd, periods_ending, periods_churned, renewal_churn_rate, is_warmup_month, is_churn_unobservable |
| mart_cohort_retention | cohort × first_plan_group × months_since_signup | cohort_size, active_users, retention_rate, retention_vs_month0 |
| mart_churn_by_segment | dimension × segment | users, churners, churn_rate, share_of_users, churn_lift_vs_overall |
| mart_value_at_risk | auto-renew × plan × price band | users, churners, churn_rate, monthly_revenue_lost_ntd, annualised_revenue_lost_ntd_assumption, share_of_revenue_lost, value_at_risk_rank |
| mart_ltv_by_segment | dimension × segment | customers, avg_value_12m_ntd, share_active_month_12, value_rank |
| mart_daily_revenue | day | revenue_ntd, paid_or_renewal_txns |
| mart_data_quality | check | affected_rows, total_rows |
