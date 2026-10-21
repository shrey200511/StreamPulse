-- Grain: one row per raw log row (SAMPLED users only; may contain duplicates).

with source as (

    select * from {{ source('kkbox', 'user_logs') }}

)

select
    trim(msno)                                   as member_id,
    {{ parse_yyyymmdd(adapter.quote('date')) }}  as activity_date,
    num_25                                       as plays_under_25pct,
    num_50                                       as plays_25_50pct,
    num_75                                       as plays_50_75pct,
    num_985                                      as plays_75_985pct,
    num_100                                      as plays_complete,
    num_unq                                      as unique_songs,
    total_secs                                   as listen_secs_raw,
    source_file
from source
