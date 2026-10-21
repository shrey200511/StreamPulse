-- Grain: one row per member in the churn-label population (memberships expiring March 2017).
-- Phase 5 model input + Phase 3/4 segment attributes.
--
-- LEAKAGE RULE: every feature uses information dated ON OR BEFORE feature_cutoff_date
-- (28 Feb 2017). The churn window opens in March, so nothing here can "see" the outcome.
-- Example of what this prevents: a cancel row or a renewal in March 2017 would almost
-- perfectly predict the label, but in real life you would not have it yet.

{% set cutoff = "date '" ~ var('feature_cutoff_date') ~ "'" %}

with labels as (

    select * from {{ ref('stg_kkbox__churn_labels') }}

),

subs_before_cutoff as (

    select * from {{ ref('fct_subscriptions') }}
    where start_date <= {{ cutoff }}

),

last_period as (

    -- The plan the member was on going into the churn window = latest period before cutoff.
    select * from (
        select
            *,
            row_number() over (partition by member_id order by start_date desc, period_number desc) as rn
        from subs_before_cutoff
    ) ranked
    where rn = 1

),

history as (

    select
        member_id,
        count(*)                                                   as n_periods_before_cutoff,
        sum(case when was_cancelled and cancel_date <= {{ cutoff }} then 1 else 0 end) as n_cancels_before_cutoff,
        sum(case when is_reactivation then 1 else 0 end)           as n_reactivations,
        count(distinct payment_method_id)                          as n_payment_methods,
        min(start_date)                                            as first_start_date,
        sum(amount_paid_ntd)                                       as paid_to_date_ntd
    from subs_before_cutoff
    group by member_id

),

activity as (

    -- Listening in the 30 days up to the cutoff, and the 30 days before that (for a trend).
    select
        member_id,
        count(distinct case when activity_date > {{ add_days(cutoff, -30) }} then activity_date end) as active_days_30d,
        sum(case when activity_date > {{ add_days(cutoff, -30) }} then listen_minutes else 0 end)    as listen_minutes_30d,
        sum(case when activity_date > {{ add_days(cutoff, -30) }} then plays_total else 0 end)       as plays_30d,
        sum(case when activity_date > {{ add_days(cutoff, -30) }} then plays_mostly_complete else 0 end) as plays_complete_30d,
        sum(case when activity_date > {{ add_days(cutoff, -30) }} then unique_songs else 0 end)      as unique_songs_30d,
        count(distinct case when activity_date <= {{ add_days(cutoff, -30) }} then activity_date end) as active_days_prev_30d,
        sum(case when activity_date <= {{ add_days(cutoff, -30) }} then listen_minutes else 0 end)   as listen_minutes_prev_30d,
        max(activity_date)                                                                           as last_active_date
    from {{ ref('fct_daily_activity') }}
    where activity_date <= {{ cutoff }}
      and activity_date > {{ add_days(cutoff, -60) }}
    group by member_id

),

members as (

    select * from {{ ref('dim_members') }}

)

select
    l.member_id,
    l.is_churn,
    m.in_log_sample,
    lp.member_id is not null                                       as has_history_before_cutoff,

    -- plan going into the churn window
    lp.plan_days                                                   as last_plan_days,
    lp.plan_length_bucket                                          as last_plan_length_bucket,
    lp.amount_paid_ntd                                             as last_amount_paid_ntd,
    lp.list_price_ntd                                              as last_list_price_ntd,
    lp.monthly_price_ntd                                           as last_monthly_price_ntd,
    case
        when lp.monthly_price_ntd is null then 'unknown'
        when lp.monthly_price_ntd = 0     then '0 (free)'
        when lp.monthly_price_ntd < 100   then '1-99'
        when lp.monthly_price_ntd < 130   then '100-129'
        when lp.monthly_price_ntd < 150   then '130-149'
        else '150+'
    end                                                            as monthly_price_bucket,
    lp.is_discounted                                               as last_is_discounted,
    lp.is_free                                                     as last_is_free,
    lp.is_auto_renew                                               as last_is_auto_renew,
    lp.payment_method_id                                           as last_payment_method_id,
    lp.was_cancelled and lp.cancel_date <= {{ cutoff }}            as last_period_cancelled_before_cutoff,
    -- Use the end date AS KNOWN AT CUTOFF: a cancel made in March would shorten
    -- effective_end_date, and using it here would leak the future.
    {{ days_between(cutoff, "case when lp.was_cancelled and lp.cancel_date <= " ~ cutoff ~
                            " then lp.effective_end_date else lp.original_expire_date end") }}
                                                                   as days_to_expiry_at_cutoff,
    lp.start_date                                                  as last_period_start_date,

    -- history
    h.n_periods_before_cutoff,
    h.n_cancels_before_cutoff,
    h.n_reactivations,
    h.n_payment_methods,
    {{ days_between('h.first_start_date', cutoff) }}               as tenure_days,
    h.paid_to_date_ntd,

    -- member attributes
    m.age,
    m.age_bucket,
    m.gender,
    m.city_id,
    m.registration_channel_id,
    {{ days_between('m.registration_date', cutoff) }}              as days_since_registration,

    -- listening (only meaningful when in_log_sample; NULL for everyone else, never 0)
    case when m.in_log_sample then coalesce(a.active_days_30d, 0) end       as active_days_30d,
    case when m.in_log_sample then coalesce(a.listen_minutes_30d, 0) end    as listen_minutes_30d,
    case when m.in_log_sample then coalesce(a.plays_30d, 0) end             as plays_30d,
    case when m.in_log_sample then {{ safe_ratio('a.plays_complete_30d', 'a.plays_30d') }} end as completion_rate_30d,
    case when m.in_log_sample then coalesce(a.unique_songs_30d, 0) end      as unique_songs_30d,
    case when m.in_log_sample then coalesce(a.active_days_prev_30d, 0) end  as active_days_prev_30d,
    case when m.in_log_sample then coalesce(a.listen_minutes_prev_30d, 0) end as listen_minutes_prev_30d,
    case when m.in_log_sample
         then coalesce(a.active_days_30d, 0) - coalesce(a.active_days_prev_30d, 0) end as active_days_change,
    case when m.in_log_sample
         then coalesce({{ days_between('a.last_active_date', cutoff) }}, 61) end  as days_since_last_listen  -- 61 = none in 60d

from labels l
left join members m        on l.member_id = m.member_id
left join last_period lp   on l.member_id = lp.member_id
left join history h        on l.member_id = h.member_id
left join activity a       on l.member_id = a.member_id
