-- Grain: one row per (signup cohort month, first plan group, months since signup).
-- Retention = share of a cohort that is an active subscriber at the END of month k.
-- Only genuinely new customers (registered on/after the data start) are used, so
-- pre-2015 subscribers don't pollute the early cohorts (left-censoring).
-- Counts (not just rates) are stored so Tableau can re-aggregate across plan groups.

with cohort_members as (

    select member_id, cohort_month, first_plan_group
    from {{ ref('dim_members') }}
    where is_new_customer

),

cohort_sizes as (

    select cohort_month, first_plan_group, count(*) as cohort_size
    from cohort_members
    group by cohort_month, first_plan_group

),

activity as (

    -- For each cohort member, every month they were active, as "months since signup".
    select
        c.cohort_month,
        c.first_plan_group,
        {{ months_between('c.cohort_month', 'mm.month_start') }} as months_since_signup,
        count(*)                                               as active_users
    from cohort_members c
    join {{ ref('int_member_months') }} mm
        on c.member_id = mm.member_id
       and mm.month_start >= c.cohort_month
    group by 1, 2, 3

),

grid as (

    -- Every cohort x every observable month, so months with zero actives still appear.
    select cs.cohort_month, cs.first_plan_group, cs.cohort_size, s.month_start,
           {{ months_between('cs.cohort_month', 's.month_start') }} as months_since_signup
    from cohort_sizes cs
    join {{ ref('int_month_spine') }} s
        on s.month_start >= cs.cohort_month

)

select
    g.cohort_month,
    g.first_plan_group,
    g.months_since_signup,
    g.month_start                                                     as calendar_month,
    g.cohort_size,
    coalesce(a.active_users, 0)                                       as active_users,
    {{ safe_ratio('coalesce(a.active_users, 0)', 'g.cohort_size') }}  as retention_rate,
    -- FIRST_VALUE: retention relative to month 0, the classic "survival curve" view.
    {{ safe_ratio('coalesce(a.active_users, 0)',
                  'first_value(coalesce(a.active_users, 0)) over (partition by g.cohort_month, g.first_plan_group order by g.months_since_signup rows between unbounded preceding and unbounded following)') }}
                                                                      as retention_vs_month0
from grid g
left join activity a
    on  g.cohort_month = a.cohort_month
    and g.first_plan_group = a.first_plan_group
    and g.months_since_signup = a.months_since_signup
