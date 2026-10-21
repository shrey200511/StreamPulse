-- Grain: one row per known member. Says whether their listening logs were sampled in.

select
    trim(msno)      as member_id,
    sample_bucket,
    in_log_sample
from {{ source('kkbox', 'log_sample_frame') }}
