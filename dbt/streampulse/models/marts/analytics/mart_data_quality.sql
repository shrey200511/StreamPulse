-- Grain: one row per data-quality check. Feeds the README "data quality" section.
-- Every number is a COUNT of affected rows, so the README never says "some" or "a few".

with tx_raw as (select count(*) as n from {{ ref('stg_kkbox__transactions') }}),
     tx as (select * from {{ ref('int_transactions__deduped') }}),
     mem as (select * from {{ ref('stg_kkbox__members') }}),
     dim as (select * from {{ ref('dim_members') }}),
     act as (select * from {{ ref('fct_daily_activity') }})

select 'transactions' as table_name, 'duplicate rows removed' as check_name,
       (select n from tx_raw) - (select count(*) from tx) as affected_rows,
       (select n from tx_raw) as total_rows
union all
select 'transactions', 'expiry date missing/unparseable',
       (select sum(case when is_expire_missing then 1 else 0 end) from tx), (select count(*) from tx)
union all
select 'transactions', 'expiry before transaction date',
       (select sum(case when is_expire_before_txn then 1 else 0 end) from tx), (select count(*) from tx)
union all
select 'transactions', 'expiry more than max_plan_span_days after transaction',
       (select sum(case when is_expire_too_far then 1 else 0 end) from tx), (select count(*) from tx)
union all
select 'members', 'age missing or outside 10-80',
       (select sum(case when is_age_missing_or_invalid then 1 else 0 end) from mem), (select count(*) from mem)
union all
select 'members', 'gender unknown',
       (select sum(case when gender = 'unknown' then 1 else 0 end) from mem), (select count(*) from mem)
union all
select 'dim_members', 'paying member missing from members table',
       (select sum(case when not is_in_members_table and n_periods > 0 then 1 else 0 end) from dim),
       (select sum(case when n_periods > 0 then 1 else 0 end) from dim)
union all
select 'fct_daily_activity (sampled)', 'days with invalid listen seconds',
       (select sum(case when has_invalid_secs then 1 else 0 end) from act), (select count(*) from act)
