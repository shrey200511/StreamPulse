-- Grain: one row per (dimension, segment) of NEW customers.
-- Observed 12-month value: money actually paid in each customer's first 12 months.
-- Only cohorts with a full 12 months of data are used, otherwise young cohorts would
-- look "cheap" just because we haven't seen their future yet (right-censoring).

{% set last_full_cohort = "date '" ~ var('data_end_date')[:8] ~ "01'" %}

with customers as (

    select *
    from {{ ref('dim_members') }}
    where is_new_customer
      and cohort_month <= {{ add_months(last_full_cohort, -12) }}

),

first_year as (

    select
        c.member_id,
        sum(s.amount_paid_ntd)                       as paid_first_12m_ntd,
        count(*)                                     as periods_first_12m
    from customers c
    join {{ ref('fct_subscriptions') }} s
        on  c.member_id = s.member_id
        and s.start_date < {{ add_months('c.cohort_month', 12) }}
    group by c.member_id

),

active_m12 as (

    select c.member_id
    from customers c
    join {{ ref('int_member_months') }} mm
        on  c.member_id = mm.member_id
        and mm.month_start = {{ add_months('c.cohort_month', 11) }}

),

base as (

    select
        c.member_id,
        c.first_plan_group,
        cast(c.first_payment_method_id as {{ dbt.type_string() }}) as first_payment_method,
        c.age_bucket,
        coalesce(fy.paid_first_12m_ntd, 0)          as paid_first_12m_ntd,
        m12.member_id is not null                    as active_in_month_12
    from customers c
    left join first_year fy  on c.member_id = fy.member_id
    left join active_m12 m12 on c.member_id = m12.member_id

),

{% set dims = [('first_plan_group', 'first_plan_group'),
               ('first_payment_method', 'first_payment_method'),
               ('age', 'age_bucket')] %}

stacked as (
    {% for name, col in dims %}
    select
        '{{ name }}'                                                   as dimension,
        coalesce({{ col }}, 'unknown')                                 as segment,
        count(*)                                                       as customers,
        avg(paid_first_12m_ntd)                                        as avg_value_12m_ntd,
        sum(paid_first_12m_ntd)                                        as total_value_12m_ntd,
        avg(cast(case when active_in_month_12 then 1 else 0 end as {{ dbt.type_float() }})) as share_active_month_12
    from base
    group by 2   -- column 1 is a constant label; grouping by it is unnecessary
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

select
    *,
    rank() over (partition by dimension order by avg_value_12m_ntd desc) as value_rank
from stacked
