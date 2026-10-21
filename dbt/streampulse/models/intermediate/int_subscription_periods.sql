-- Grain: one row per subscription period.
-- A "period" starts with a paid/renewal (non-cancel) transaction and lasts until its
-- expiry date — or until an earlier date if the user cancelled during the period.
--
-- Why: KKBox logs cancellations as separate rows that SHORTEN the current membership.
-- To know when someone actually stopped being a member we must attach each cancel
-- row to the period it belongs to.

with txns as (

    select * from {{ ref('int_transactions__deduped') }}
    where is_valid_dates

),

sequenced as (

    select
        *,
        -- Running count of non-cancel rows per member, in time order.
        -- Each new purchase/renewal bumps the counter -> new period number.
        -- A cancel row does NOT bump it, so it inherits the number of the period it cancels.
        -- ROWS BETWEEN ... CURRENT ROW makes the running sum strictly row-by-row (no tie surprises).
        sum(case when is_cancel then 0 else 1 end) over (
            partition by member_id
            order by transaction_date, is_cancel, expire_date, transaction_key
            rows between unbounded preceding and current row
        ) as period_number
    from txns

),

period_starts as (

    select *
    from sequenced
    where not is_cancel

),

period_cancels as (

    -- If a period has several cancel rows, the earliest new expiry wins.
    select
        member_id,
        period_number,
        min(expire_date)       as cancel_expire_date,
        min(transaction_date)  as cancel_date
    from sequenced
    where is_cancel
      and period_number > 0    -- a cancel before any purchase can't be attached: dropped
    group by member_id, period_number

)

select
    p.transaction_key                                       as subscription_id,
    p.member_id,
    p.period_number,
    p.transaction_date                                      as start_date,
    p.expire_date                                           as original_expire_date,
    case
        when c.cancel_expire_date is not null and c.cancel_expire_date < p.expire_date
            then c.cancel_expire_date
        else p.expire_date
    end                                                     as effective_end_date,
    c.member_id is not null                                 as was_cancelled,
    c.cancel_date,
    p.plan_days,
    p.list_price_ntd,
    p.amount_paid_ntd,
    p.is_auto_renew,
    p.payment_method_id
from period_starts p
left join period_cancels c
    on  p.member_id = c.member_id
    and p.period_number = c.period_number
