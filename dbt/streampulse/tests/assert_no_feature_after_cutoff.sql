-- Leakage guard: no model feature may be based on a period that started after the cutoff.
select *
from {{ ref('mart_churn_features') }}
where last_period_start_date > date '{{ var("feature_cutoff_date") }}'
