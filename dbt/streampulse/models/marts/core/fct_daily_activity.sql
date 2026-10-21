-- Grain: one row per member per day with listening activity.
-- !! SAMPLED: only members with in_log_sample = true. Use rates/averages per member,
-- !! never sums as if they were population totals (multiply by 100/sample_pct at most,
-- !! and say so).

with logs as (

    -- Duplicate rows (overlap of the two log files) are removed with ROW_NUMBER.
    -- listen_secs_raw is left out of PARTITION BY on purpose: BigQuery does not allow
    -- partitioning by FLOAT64, and rows equal on every count column are the same record.
    select * from (
        select
            *,
            row_number() over (
                partition by member_id, activity_date, plays_under_25pct, plays_25_50pct,
                             plays_50_75pct, plays_75_985pct, plays_complete, unique_songs
                order by source_file
            ) as duplicate_rank
        from {{ ref('stg_kkbox__user_logs') }}
        where activity_date is not null
    ) numbered
    where duplicate_rank = 1

),

daily as (

    select
        member_id,
        activity_date,
        sum(plays_under_25pct + plays_25_50pct + plays_50_75pct + plays_75_985pct + plays_complete) as plays_total,
        sum(plays_75_985pct + plays_complete)                    as plays_mostly_complete,
        sum(plays_under_25pct)                                   as plays_skipped_early,
        sum(unique_songs)                                        as unique_songs,
        -- total_secs has impossible values (negative, or more seconds than a day has).
        -- Keep only 0..86400 per row; flag the rest so the quality report can count them.
        sum(case when listen_secs_raw between 0 and 86400 then listen_secs_raw end) as listen_secs,
        max(case when listen_secs_raw between 0 and 86400 then 0 else 1 end) = 1    as has_invalid_secs
    from logs
    group by member_id, activity_date

)

select
    {{ surrogate_key(['member_id', 'activity_date']) }}        as activity_key,
    member_id,
    activity_date,
    {{ month_start('activity_date') }}                         as activity_month,
    plays_total,
    plays_mostly_complete,
    plays_skipped_early,
    {{ safe_ratio('plays_mostly_complete', 'plays_total') }}   as completion_rate,
    {{ safe_ratio('plays_skipped_early', 'plays_total') }}     as early_skip_rate,
    unique_songs,
    listen_secs,
    listen_secs / 60.0                                         as listen_minutes,
    has_invalid_secs
from daily
