# Architecture

```mermaid
flowchart TB
    subgraph Local laptop
        K[Kaggle .7z → CSV] --> P[scripts/prepare_raw.py<br/>DuckDB streaming read<br/>explicit schemas · user-level log sample]
        P --> PQ[data/prepared/*.parquet<br/>+ sampling_report.json]
    end
    PQ --> L[scripts/load_warehouse.py<br/>WRITE_TRUNCATE]
    subgraph BigQuery sandbox
        L --> RAW[(raw)]
        RAW --> STG[dbt_dev_staging · views]
        STG --> INT[dbt_dev_intermediate · views]
        INT --> MART[(dbt_dev_marts · tables)]
    end
    MART --> NB[notebooks 03–08]
    NB --> RES[results/*.json + figures]
    MART --> EXP[scripts/export_for_tableau.py] --> CSV[dashboard/data/*.csv] --> TAB[Tableau Public]
    RES --> MEMO[memo + README findings]

    subgraph CI · GitHub Actions
        FIX[make_fixture.py<br/>SYNTHETIC] --> DUCK[(DuckDB)] --> SAME[same dbt models + tests<br/>same notebooks]
    end
```

## Decisions and why

| Decision | Why | Trade-off |
|---|---|---|
| Prepare data locally with DuckDB before loading | Streams a 30 GB CSV without needing RAM for it; Parquet keeps types and uploads faster | One extra step |
| Sample logs by **user** | Keeps per-user features correct; deterministic md5 bucket | Listening results cover 10% of users |
| Load with `WRITE_TRUNCATE` | Re-running gives the same state — essential because sandbox tables expire after 60 days | None |
| Staging & intermediate as **views**, marts as **tables** | Views cost zero storage (10 GB cap); marts are queried repeatedly | Views recompute on each read |
| No incremental models | Sandbox has no DML (`MERGE`/`INSERT`) | Full rebuild each run (fine at this size) |
| Cross-database macros (`macros/cross_db.sql`) | Same models run on BigQuery and DuckDB → CI on every push | A few macros instead of raw dialect functions |
| Subscription *periods* with cancel attachment | KKBox records cancellations as separate rows that shorten membership | Window-function logic to explain |
| Month-end snapshot for "active" | Standard, unambiguous definition | Ignores mid-month churn-and-return |
| `is_new_customer` guard for cohorts | Data starts 2015-01-01: earlier members' real first payment is unknown (left-censoring) | Smaller cohorts |
| Results written to JSON | Every number in the memo/README/resume traces back to a file | Discipline |
| Synthetic fixture quarantined | CI needs data; fake numbers must never leak into findings | Separate folder, git-ignored |

## Layers

| Layer | Rule |
|---|---|
| **staging** | One model per source table. Rename, cast, parse dates, null-out junk. No joins, no business logic. |
| **intermediate** | Reusable building blocks: dedupe, periods, month spine, member-months. Not for end users. |
| **marts/core** | Facts and dimensions with documented grain and tests. |
| **marts/analytics** | Question-specific tables for notebooks and Tableau. |
