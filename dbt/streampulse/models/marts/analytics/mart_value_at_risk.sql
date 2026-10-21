-- Grain: one row per behavioural segment (auto-renew x plan length x price band)
-- of the churn-label population.
-- "Revenue lost to churn" = monthly-equivalent price of members who actually churned.
-- Annualised figures assume a churner would otherwise have stayed 12 more months —
-- an explicit ASSUMPTION, labelled as such everywhere it is shown.

with f as (

    select * from {{ ref('mart_churn_features') }}
    where has_history_before_cutoff

),

segments as (

    select
        case when last_is_auto_renew then 'auto-renew on' else 'auto-renew off' end as auto_renew,
        last_plan_length_bucket                                                    as plan_length,
        monthly_price_bucket                                                       as price_band,
        count(*)                                                                   as users,
        sum(case when is_churn then 1 else 0 end)                                  as churners,
        sum(coalesce(last_monthly_price_ntd, 0))                                   as monthly_revenue_ntd,
        sum(case when is_churn then coalesce(last_monthly_price_ntd, 0) else 0 end) as monthly_revenue_lost_ntd
    from f
    group by 1, 2, 3

)

select
    auto_renew,
    plan_length,
    price_band,
    auto_renew || ' | ' || plan_length || ' | ' || price_band                     as segment_label,
    users,
    churners,
    {{ safe_ratio('churners', 'users') }}                                          as churn_rate,
    monthly_revenue_ntd,
    monthly_revenue_lost_ntd,
    monthly_revenue_lost_ntd * 12                                                  as annualised_revenue_lost_ntd_assumption,
    {{ safe_ratio('monthly_revenue_lost_ntd', 'sum(monthly_revenue_lost_ntd) over ()') }} as share_of_revenue_lost,
    rank() over (order by monthly_revenue_lost_ntd desc)                           as value_at_risk_rank
from segments
