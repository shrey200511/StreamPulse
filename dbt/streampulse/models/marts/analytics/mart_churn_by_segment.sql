-- Grain: one row per (dimension, segment) for the churn-label population.
-- Long ("tidy") format: one table answers "churn rate by X" for every X, and Tableau
-- can filter on `dimension` instead of needing one sheet per table.
-- Churn here = KKBox's official label (memberships expiring March 2017).

with f as (

    select * from {{ ref('mart_churn_features') }}
    where has_history_before_cutoff

),

{% set dims = [
    ('plan_length',      'last_plan_length_bucket'),
    ('auto_renew',       "case when last_is_auto_renew then 'auto-renew on' else 'auto-renew off' end"),
    ('payment_method',   "cast(last_payment_method_id as " ~ dbt.type_string() ~ ")"),
    ('monthly_price',    'monthly_price_bucket'),
    ('discounted',       "case when last_is_discounted then 'paid below list price' else 'paid list price' end"),
    ('cancelled_before', "case when last_period_cancelled_before_cutoff then 'cancelled before cutoff' else 'not cancelled' end"),
    ('age',              'age_bucket'),
    ('tenure',           "case when tenure_days < 90 then '01. <3 months' when tenure_days < 365 then '02. 3-12 months' else '03. 12+ months' end"),
] %}

stacked as (

    {% for name, expr in dims %}
    select
        '{{ name }}'                                   as dimension,
        {{ expr }}                                     as segment,
        count(*)                                       as users,
        sum(case when is_churn then 1 else 0 end)      as churners,
        avg(last_monthly_price_ntd)                    as avg_monthly_price_ntd
    from f
    group by 2   -- column 1 is a constant label; grouping by it is unnecessary
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

)

select
    dimension,
    coalesce(segment, 'unknown')                                          as segment,
    users,
    churners,
    {{ safe_ratio('churners', 'users') }}                                 as churn_rate,
    -- Window functions over each dimension: share of users, and lift vs the overall rate.
    {{ safe_ratio('users', 'sum(users) over (partition by dimension)') }} as share_of_users,
    {{ safe_ratio('churners', 'users') }}
      / {{ safe_ratio('sum(churners) over (partition by dimension)',
                      'sum(users) over (partition by dimension)') }}      as churn_lift_vs_overall,
    avg_monthly_price_ntd
from stacked
