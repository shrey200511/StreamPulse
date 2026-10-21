-- Grain: one row per calendar day with at least one payment.
-- Daily series for the Phase 8 seasonal forecast: monthly data has only ~27 points
-- (too few to learn yearly seasonality), but daily revenue has ~820 points and a strong
-- weekly / billing-cycle pattern that a seasonal model can learn.

select
    start_date                                   as revenue_date,
    sum(amount_paid_ntd)                         as revenue_ntd,
    count(*)                                     as paid_or_renewal_txns,
    sum(case when is_auto_renew then amount_paid_ntd else 0 end) as auto_renew_revenue_ntd
from {{ ref('fct_subscriptions') }}
group by start_date
