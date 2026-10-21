-- A period cannot end before it starts. If this fails, the cancel-attachment logic is wrong.
select *
from {{ ref('fct_subscriptions') }}
where effective_end_date < start_date
