# Sampling note — read this before quoting any listening number

## What is sampled

| Table | Kept | Why |
|---|---|---|
| members | **100%** | small |
| transactions (+ v2) | **100%** | small; all revenue, retention and churn-rate numbers use complete data |
| churn labels (train_v2) | **100%** | small |
| user_logs (+ v2) | **SAMPLE_PCT % of users** (default 10%) | far larger than the BigQuery sandbox's 10 GB storage cap |

## How

A member is in the sample if

```
int(first 8 hex characters of md5(msno), 16) % 100  <  SAMPLE_PCT
```

* **By user, not by row.** A row sample would give each member a random 10% of their days, so
  "active days in the last 30" would be wrong for everyone. A user sample keeps every day for 10% of users.
* **Deterministic.** Same file in → same users out, on any machine. Anyone can check it.
  BigQuery equivalent: `MOD(CAST(CONCAT('0x', SUBSTR(TO_HEX(MD5(msno)), 1, 8)) AS INT64), 100)`.
* **md5 is unrelated to behaviour**, so the sample behaves like a simple random sample of users.

## Effect on results

| Result | Affected? | How it's handled |
|---|---|---|
| Retention, cohorts, revenue, ARPU, LTV, value at risk (Phases 3–4) | **No** | built from complete transactions |
| Churn rates by segment | **No** | complete labels + transactions |
| Churn model A (Phase 5) | **No** | no listening features |
| Churn model B (Phase 5) | **Yes** | trained on sampled users only; compared with model A on the *same* users so the gain from listening features is fair |
| `fct_daily_activity`, listening tiles in the dashboard | **Yes** | labelled "10% user sample"; shown as per-user averages and rates, never as totals |
| Forecast (Phase 8) | **No** | built from transactions |

## Representativeness check (filled from `data/prepared/sampling_report.json`)

| | Full label population | Users in log sample |
|---|---|---|
| Members | _run prepare_raw.py_ | _run prepare_raw.py_ |
| Churn rate | _run prepare_raw.py_ | _run prepare_raw.py_ |

If the two churn rates are close (the difference should be within normal sampling noise for a sample this
size), the sample is representative on the outcome that matters most.

## Choosing SAMPLE_PCT

`load_warehouse.py` prints the raw dataset's size. Keep raw at **≤ 7 GB** so the dbt tables fit under the
10 GB cap. If it's over, re-run `prepare_raw.py` with a smaller `--sample-pct` (e.g. 5) and update this note.
