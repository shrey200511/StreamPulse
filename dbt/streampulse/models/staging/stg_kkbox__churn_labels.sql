-- Grain: one row per labelled member (memberships expiring in March 2017).

select
    trim(msno)      as member_id,
    is_churn = 1    as is_churn
from {{ source('kkbox', 'churn_labels') }}
