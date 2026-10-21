-- A retention rate outside 0..1 means the cohort join is double-counting members.
select *
from {{ ref('mart_cohort_retention') }}
where retention_rate < 0 or retention_rate > 1
