-- Grain: one row per member per month in which they were an ACTIVE subscriber at month-end.
-- "Active at month-end" = some subscription period covers the last day of the month.
-- This is the base for active-subscriber counts, cohort retention and the forecast.

with periods as (

    select * from {{ ref('int_subscription_periods') }}

),

spine as (

    select * from {{ ref('int_month_spine') }}

)

select
    s.month_start,
    p.member_id,
    -- If two periods overlap (early renewal), count the member once; keep the latest plan.
    max(p.start_date) as covering_period_start_date
from spine s
join periods p
    on  p.start_date         <= s.month_end      -- period started on/before month-end
    and p.effective_end_date >= s.month_end      -- and had not ended yet
group by s.month_start, p.member_id
