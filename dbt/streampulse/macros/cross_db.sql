{#-
  Small cross-database helpers so the SAME models run on BigQuery (real data)
  and DuckDB (laptop + CI on synthetic data). Each macro uses adapter.dispatch:
  dbt picks bigquery__<name> or duckdb__<name> based on the active target.
-#}

{# KKBox stores dates as integers like 20170228. Turn them into real DATEs.
   SAFE / TRY versions return NULL instead of failing on junk values like 0. #}
{% macro parse_yyyymmdd(col) %}
  {{ return(adapter.dispatch('parse_yyyymmdd')(col)) }}
{% endmacro %}

{% macro bigquery__parse_yyyymmdd(col) -%}
  SAFE.PARSE_DATE('%Y%m%d', CAST({{ col }} AS STRING))
{%- endmacro %}

{% macro default__parse_yyyymmdd(col) -%}
  CAST(TRY_STRPTIME(CAST({{ col }} AS VARCHAR), '%Y%m%d') AS DATE)
{%- endmacro %}


{# First day of the month, always returned as DATE. #}
{% macro month_start(col) -%}
  CAST({{ dbt.date_trunc('month', col) }} AS DATE)
{%- endmacro %}


{# Add n days / months to a date and keep the DATE type. #}
{% macro add_days(col, n) -%}
  CAST({{ dbt.dateadd('day', n, col) }} AS DATE)
{%- endmacro %}

{% macro add_months(col, n) -%}
  CAST({{ dbt.dateadd('month', n, col) }} AS DATE)
{%- endmacro %}


{# Last day of the month. #}
{% macro month_end(col) -%}
  {{ add_days(add_months(month_start(col), 1), -1) }}
{%- endmacro %}


{# Whole days between two dates (end - start). #}
{% macro days_between(start_col, end_col) -%}
  {{ dbt.datediff(start_col, end_col, 'day') }}
{%- endmacro %}


{# Whole calendar months between two month-start dates. #}
{% macro months_between(start_col, end_col) -%}
  {{ dbt.datediff(start_col, end_col, 'month') }}
{%- endmacro %}


{# A one-column table of month-start dates, inclusive. Used as a "spine". #}
{% macro month_series(start_date, end_date) %}
  {{ return(adapter.dispatch('month_series')(start_date, end_date)) }}
{% endmacro %}

{% macro bigquery__month_series(start_date, end_date) -%}
  SELECT month_start
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE '{{ start_date }}', DATE '{{ end_date }}', INTERVAL 1 MONTH)) AS month_start
{%- endmacro %}

{% macro default__month_series(start_date, end_date) -%}
  SELECT CAST(generate_series AS DATE) AS month_start
  FROM generate_series(DATE '{{ start_date }}', DATE '{{ end_date }}', INTERVAL 1 MONTH)
{%- endmacro %}


{# Deterministic surrogate key from several columns (md5 hex string). #}
{% macro surrogate_key(cols) -%}
  {%- set parts = [] -%}
  {%- for c in cols -%}
    {%- do parts.append("COALESCE(CAST(" ~ c ~ " AS " ~ dbt.type_string() ~ "), '_null_')") -%}
    {%- if not loop.last %}{%- do parts.append("'|'") -%}{%- endif -%}
  {%- endfor -%}
  {{ dbt.hash(dbt.concat(parts)) }}
{%- endmacro %}


{# Ratio that returns NULL instead of erroring when the denominator is 0. #}
{% macro safe_ratio(num, den) -%}
  (CAST({{ num }} AS {{ dbt.type_float() }}) / NULLIF({{ den }}, 0))
{%- endmacro %}
