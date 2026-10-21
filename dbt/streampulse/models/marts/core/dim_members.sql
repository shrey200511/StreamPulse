-- Grain: one row per member seen in ANY table (members, transactions, labels).
-- Built from the union of ids so every fact table's member_id has a match here
-- (some paying users are missing from members_v3).

with all_ids as (

    select distinct member_id from (
        select member_id from {{ ref('stg_kkbox__members') }}
        union all
        select member_id from {{ ref('stg_kkbox__transactions') }}
        union all
        select member_id from {{ ref('stg_kkbox__churn_labels') }}
    ) ids

),

members as (

    select * from {{ ref('stg_kkbox__members') }}

),

subs as (

    select
        member_id,
        min(start_date)                                   as first_period_start_date,
        max(effective_end_date)                           as last_effective_end_date,
        count(*)                                          as n_periods,
        sum(amount_paid_ntd)                              as lifetime_paid_ntd,
        sum(case when was_cancelled then 1 else 0 end)    as n_cancelled_periods
    from {{ ref('fct_subscriptions') }}
    group by member_id

),

first_period as (

    -- The attributes of each member's FIRST observed plan (used to segment cohorts / LTV).
    select member_id, plan_length_bucket, is_auto_renew, payment_method_id, is_free
    from (
        select
            member_id, plan_length_bucket, is_auto_renew, payment_method_id, is_free,
            row_number() over (partition by member_id order by start_date, period_number) as rn
        from {{ ref('fct_subscriptions') }}
    ) ranked
    where rn = 1

)

select
    i.member_id,
    m.city_id,
    m.age,
    case
        when m.age is null then 'unknown'
        when m.age < 20 then '<20'
        when m.age < 25 then '20-24'
        when m.age < 30 then '25-29'
        when m.age < 40 then '30-39'
        else '40+'
    end                                                    as age_bucket,
    coalesce(m.gender, 'unknown')                          as gender,
    m.registration_channel_id,
    m.registration_date,
    m.member_id is not null                                as is_in_members_table,

    s.first_period_start_date,
    {{ month_start('s.first_period_start_date') }}         as cohort_month,
    -- Left-censoring guard: our data starts 2015-01-01. Someone registered earlier may
    -- have paid before that, so their "first" period here is not their real first.
    -- Only members registered on/after the data start are treated as genuinely new.
    coalesce(m.registration_date >= date '{{ var("data_start_date") }}', false)
        and s.first_period_start_date is not null          as is_new_customer,
    s.last_effective_end_date,
    s.n_periods,
    s.lifetime_paid_ntd,
    s.n_cancelled_periods,

    case
        when fp.is_free then 'Free / promo start'
        when fp.plan_length_bucket = '01. <=7 days (trial/short)' then 'Short plan start'
        when fp.plan_length_bucket = '02. ~1 month' and fp.is_auto_renew then 'Monthly, auto-renew'
        when fp.plan_length_bucket = '02. ~1 month' then 'Monthly, manual'
        when fp.plan_length_bucket is not null then 'Multi-month plan'
    end                                                    as first_plan_group,
    fp.payment_method_id                                   as first_payment_method_id,

    l.member_id is not null                                as is_in_label_population,
    l.is_churn                                             as is_churn_label,
    coalesce(f.in_log_sample, false)                       as in_log_sample

from all_ids i
left join members m                       on i.member_id = m.member_id
left join subs s                          on i.member_id = s.member_id
left join first_period fp                 on i.member_id = fp.member_id
left join {{ ref('stg_kkbox__churn_labels') }} l on i.member_id = l.member_id
left join {{ ref('stg_kkbox__log_sample_frame') }} f on i.member_id = f.member_id
