-- Grain: one row per subscription period (one paid/renewal transaction).
-- Adds: what happened NEXT (renewed? churned? came back later?) using LAG/LEAD.
--
-- Churn rule (same as KKBox's label): a period ends in churn if the member does not
-- start a new period within 30 days after it ends. We can only judge that when those
-- 30 days are inside our data, otherwise is_churned is NULL (not observable).

with periods as (

    select * from {{ ref('int_subscription_periods') }}

),

with_neighbours as (

    select
        *,
        -- LEAD looks one row ahead in the member's timeline: when did the NEXT period start?
        lead(start_date) over (
            partition by member_id order by start_date, period_number
        ) as next_period_start_date,
        -- LAG looks one row back: when did the PREVIOUS period end?
        lag(effective_end_date) over (
            partition by member_id order by start_date, period_number
        ) as previous_period_end_date
    from periods

)

select
    subscription_id,
    member_id,
    period_number,
    start_date,
    original_expire_date,
    effective_end_date,
    {{ month_start('start_date') }}                                    as start_month,
    {{ month_start('effective_end_date') }}                            as end_month,
    plan_days,
    case
        when plan_days <= 7   then '01. <=7 days (trial/short)'
        when plan_days <= 31  then '02. ~1 month'
        when plan_days <= 100 then '03. ~3 months'
        when plan_days <= 200 then '04. ~6 months'
        else                       '05. 12+ months'
    end                                                                as plan_length_bucket,
    list_price_ntd,
    amount_paid_ntd,
    list_price_ntd - amount_paid_ntd                                   as discount_ntd,
    amount_paid_ntd < list_price_ntd                                   as is_discounted,
    amount_paid_ntd = 0                                                as is_free,
    -- Normalise every plan to a 30-day price so a yearly and a monthly plan are comparable.
    case when plan_days > 0 then cast(amount_paid_ntd as {{ dbt.type_float() }}) * 30 / plan_days end as monthly_price_ntd,
    is_auto_renew,
    payment_method_id,
    was_cancelled,
    cancel_date,
    period_number = 1                                                  as is_first_observed_period,
    previous_period_end_date,
    -- Came back after a gap longer than the churn window = a "reactivation".
    previous_period_end_date is not null
        and {{ days_between('previous_period_end_date', 'start_date') }} > {{ var('churn_grace_days') }}
                                                                       as is_reactivation,
    next_period_start_date,

    -- Is the 30-day window after this period fully inside the data?
    {{ add_days('effective_end_date', var('churn_grace_days')) }} <= date '{{ var("data_end_date") }}'
                                                                       as is_churn_observable,
    case
        when {{ add_days('effective_end_date', var('churn_grace_days')) }} > date '{{ var("data_end_date") }}'
            then null                                                  -- can't know yet
        when next_period_start_date is null
            then true                                                  -- never came back
        when next_period_start_date > {{ add_days('effective_end_date', var('churn_grace_days')) }}
            then true                                                  -- came back, but too late
        else false                                                     -- renewed in time
    end                                                                as is_churned

from with_neighbours
