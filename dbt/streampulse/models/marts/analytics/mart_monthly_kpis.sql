-- Grain: one row per calendar month.
-- Executive KPIs + the series used by the Phase 8 forecast.

with spine as (

    select * from {{ ref('int_month_spine') }}

),

active as (

    select month_start, count(*) as active_subscribers
    from {{ ref('int_member_months') }}
    group by month_start

),

subs as (

    select * from {{ ref('fct_subscriptions') }}

),

revenue as (

    -- Cash basis: money is counted in the month the payment happened.
    select
        start_month                                     as month_start,
        sum(amount_paid_ntd)                            as revenue_ntd,
        count(*)                                        as paid_or_renewal_txns,
        sum(case when is_first_observed_period then 1 else 0 end) as first_observed_periods
    from subs
    group by start_month

),

new_customers as (

    select cohort_month as month_start, count(*) as new_customers
    from {{ ref('dim_members') }}
    where is_new_customer
    group by cohort_month

),

endings as (

    -- Renewal churn: of the periods that ENDED this month (and are observable),
    -- how many were not followed by a new period within 30 days?
    select
        end_month                                       as month_start,
        count(*)                                        as periods_ending,
        sum(case when is_churned then 1 else 0 end)     as periods_churned
    from subs
    where is_churn_observable
    group by end_month

)

select
    s.month_start,
    s.month_end,
    coalesce(a.active_subscribers, 0)                                  as active_subscribers,
    coalesce(n.new_customers, 0)                                       as new_customers,
    coalesce(r.revenue_ntd, 0)                                         as revenue_ntd,
    coalesce(r.paid_or_renewal_txns, 0)                                as paid_or_renewal_txns,
    {{ safe_ratio('r.revenue_ntd', 'a.active_subscribers') }}          as arpu_ntd,
    e.periods_ending,
    e.periods_churned,
    -- Only report the rate when EVERY period ending this month has its full 30-day
    -- window inside the data; otherwise the month is half-observed and the rate is biased.
    case when {{ add_days('s.month_end', var('churn_grace_days')) }} <= date '{{ var("data_end_date") }}'
         then {{ safe_ratio('e.periods_churned', 'e.periods_ending') }}
    end                                                                as renewal_churn_rate,
    -- Month-over-month change with LAG (window over the whole series, ordered by month).
    coalesce(a.active_subscribers, 0)
      - lag(coalesce(a.active_subscribers, 0)) over (order by s.month_start) as active_subscribers_change,
    -- Left-censoring warning: the first months under-count actives, because members who
    -- paid for long plans before 2015 only show up when they next renew.
    s.month_start < {{ add_months("date '" ~ var('data_start_date') ~ "'", 6) }} as is_warmup_month,
    {{ add_days('s.month_end', var('churn_grace_days')) }} > date '{{ var("data_end_date") }}' as is_churn_unobservable
from spine s
left join active a         on s.month_start = a.month_start
left join revenue r        on s.month_start = r.month_start
left join new_customers n  on s.month_start = n.month_start
left join endings e        on s.month_start = e.month_start
