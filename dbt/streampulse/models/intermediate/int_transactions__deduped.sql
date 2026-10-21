-- Grain: one row per DISTINCT transaction.
-- Two jobs: (1) remove exact duplicates (the v1 and v2 files overlap),
--           (2) flag rows whose dates make no sense, instead of silently dropping them.

with transactions as (

    select * from {{ ref('stg_kkbox__transactions') }}

),

numbered as (

    select
        *,
        -- Window function: number identical rows 1, 2, 3 ... within each group of duplicates.
        -- PARTITION BY every business column = "rows that are the same transaction".
        row_number() over (
            partition by member_id, payment_method_id, plan_days, list_price_ntd, amount_paid_ntd,
                         is_auto_renew, is_cancel, transaction_date, expire_date
            order by source_file          -- prefer the original file if a row appears in both
        ) as duplicate_rank
    from transactions

),

deduped as (

    select * from numbered
    where duplicate_rank = 1             -- keep one copy of each duplicate group

)

select
    {{ surrogate_key(['member_id', 'payment_method_id', 'plan_days', 'list_price_ntd', 'amount_paid_ntd',
                      'is_auto_renew', 'is_cancel', 'transaction_date', 'expire_date']) }} as transaction_key,
    member_id,
    payment_method_id,
    plan_days,
    list_price_ntd,
    amount_paid_ntd,
    is_auto_renew,
    is_cancel,
    transaction_date,
    expire_date,
    source_file,

    -- Data-quality flags (counted in the data quality report, excluded from period logic)
    expire_date is null                                                            as is_expire_missing,
    expire_date < transaction_date                                                 as is_expire_before_txn,
    {{ days_between('transaction_date', 'expire_date') }} > {{ var('max_plan_span_days') }} as is_expire_too_far,
    (
        expire_date is not null
        and expire_date >= transaction_date
        and {{ days_between('transaction_date', 'expire_date') }} <= {{ var('max_plan_span_days') }}
    )                                                                              as is_valid_dates

from deduped
