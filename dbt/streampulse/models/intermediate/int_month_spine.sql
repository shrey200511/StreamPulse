-- Grain: one row per calendar month in the data window.
-- A "spine" guarantees every month appears even if nothing happened in it,
-- so charts and window functions never silently skip a month.

with months as (

    {{ month_series(var('data_start_date'), var('data_end_date')[:8] ~ '01') }}

)

select
    month_start,
    {{ month_end('month_start') }} as month_end
from months
