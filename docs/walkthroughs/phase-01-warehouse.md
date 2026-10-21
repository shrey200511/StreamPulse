# Phase 1 — Warehouse: load raw data, sample the logs

## Run

1. Kaggle → *KKBox's Churn Prediction Challenge* → accept the rules → download.
2. Extract into `data/raw/` (7-Zip): `members_v3.csv`, `transactions.csv`, `transactions_v2.csv`,
   `train_v2.csv`, `user_logs.csv`, `user_logs_v2.csv`. `user_logs.csv` is huge — an external drive is fine
   (pass `--raw-dir`). Delete the extracted logs after step 3 if disk is tight.
3. Prepare (one-time, ~minutes to an hour depending on disk speed):

```powershell
python scripts/prepare_raw.py --raw-dir data/raw --out-dir data/prepared --sample-pct 10 --memory-limit 4GB
```
4. Load (re-run any time the sandbox expires the tables):
```powershell
python scripts/load_warehouse.py --target bigquery --project YOUR_PROJECT_ID
```
5. Paste the printed `sampling_report.json` and the storage line into chat / `docs/sampling.md`.

## Key code — the user-level sample (`prepare_raw.py`)

```sql
SELECT msno,
       CAST(('0x' || substr(md5(msno), 1, 8))::UBIGINT % 100 AS INTEGER) AS sample_bucket,
       CAST(('0x' || substr(md5(msno), 1, 8))::UBIGINT % 100 AS INTEGER) < 10 AS in_log_sample
FROM users
```

| Part | What it does | Why |
|---|---|---|
| `md5(msno)` | hashes the user id to 32 hex characters | output looks random but is fully determined by the id |
| `substr(…, 1, 8)` | keeps the first 8 hex chars | 8 hex = 32 bits, plenty to spread users evenly |
| `('0x' \|\| …)::UBIGINT` | reads hex as an integer | so we can take a remainder |
| `% 100` | bucket 0–99 | each bucket ≈ 1% of users |
| `< 10` | buckets 0–9 → in sample | 10% of users; change `--sample-pct` to resize |
| `FROM users` | union of ids from members, transactions, labels | every known user gets a bucket, even ones with no logs |

```sql
SELECT l.* FROM (logs) l SEMI JOIN (SELECT msno FROM frame WHERE in_log_sample) s USING (msno)
```

| Part | What it does | Why |
|---|---|---|
| `SEMI JOIN` | keep log rows whose user is in the sample | like `WHERE msno IN (…)`, never duplicates rows |
| DuckDB streaming | reads the CSV in chunks | a 30 GB file never needs to fit in RAM |
| `COPY … TO parquet` | typed, compressed output | faster upload; BigQuery keeps the types |

## Key code — re-runnable load (`load_warehouse.py`)

| Line | What it does | Why |
|---|---|---|
| `create_dataset(ds, exists_ok=True)` | creates `raw` only if missing | safe to re-run |
| `SourceFormat.PARQUET` | load Parquet | schema travels with the file; no type guessing |
| `WriteDisposition.WRITE_TRUNCATE` | replace the table | idempotent: twice = once. Needed because sandbox tables expire after 60 days |
| `t.num_bytes` summed, warning > 70% | storage check | dbt marts need room under the 10 GB cap |

## ✅ Checklist
- [ ] `sampling_report.json` exists; note `user_logs_full.rows`, `rows_in_sample`, and both churn rates
- [ ] Label churn rate in sample ≈ full population (difference within sampling noise)
- [ ] Raw storage printed ≤ ~7 GB
- [ ] Row counts in BigQuery match the report
- [ ] `docs/sampling.md` table filled in

## 🎤 Interview questions
| Q | Answer |
|---|---|
| Why sample users instead of rows? | "A row sample gives everyone a random 10% of their days, which breaks per-user features like 'active days in the last 30'. Sampling users keeps complete histories for 10% of people." |
| How do you know the sample is representative? | "md5 is unrelated to behaviour, so it acts like simple random sampling. I checked the outcome: churn rate in the sample vs the full label population (numbers in sampling_report.json). And everything not about listening uses 100% of the data." |
| What happens when the sandbox deletes your tables? | "Nothing breaks: the loader truncates and reloads from Parquet, then `dbt build` rebuilds everything. Reproducibility was a design requirement because of the 60-day expiry." |
