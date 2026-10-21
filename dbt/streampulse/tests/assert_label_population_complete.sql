-- Every labelled member must appear exactly once in the feature table (no silent drops).
select
    (select count(*) from {{ ref('stg_kkbox__churn_labels') }}) as labels,
    (select count(*) from {{ ref('mart_churn_features') }})     as features
from (select 1 as x) one_row
where (select count(*) from {{ ref('stg_kkbox__churn_labels') }})
   <> (select count(*) from {{ ref('mart_churn_features') }})
