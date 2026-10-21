"""Phase 1b — load the prepared Parquet files into the warehouse's `raw` dataset.

Re-runnable by design: every table is replaced (WRITE_TRUNCATE), so running it twice
gives the same result. That matters because the BigQuery sandbox deletes every table
after 60 days — when that happens you just run this again, then `dbt build`.

Usage:
  python scripts/load_warehouse.py --target bigquery --project YOUR_PROJECT_ID
  python scripts/load_warehouse.py --target duckdb   # local file warehouse/streampulse.duckdb
"""
from __future__ import annotations

import argparse
from pathlib import Path

TABLES = ["members", "transactions", "churn_labels", "log_sample_frame", "user_logs"]
SANDBOX_STORAGE_BYTES = 10 * 1024**3


def load_bigquery(src: Path, project: str, dataset: str, location: str) -> None:
    from google.cloud import bigquery

    client = bigquery.Client(project=project)
    ds = bigquery.Dataset(f"{project}.{dataset}")
    ds.location = location
    client.create_dataset(ds, exists_ok=True)  # no-op if it exists

    total = 0
    for name in TABLES:
        table_id = f"{project}.{dataset}.{name}"
        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.PARQUET,
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # idempotent reload
        )
        with open(src / f"{name}.parquet", "rb") as fh:
            client.load_table_from_file(fh, table_id, job_config=job_config).result()
        t = client.get_table(table_id)
        total += t.num_bytes
        print(f"  {table_id:55s} {t.num_rows:>14,d} rows {t.num_bytes / 1e9:7.2f} GB  expires {t.expires}")

    print(f"raw storage: {total / 1e9:.2f} GB of the 10 GB sandbox cap (dbt marts need room too)")
    if total > 0.7 * SANDBOX_STORAGE_BYTES:
        print("WARNING: raw uses >70% of the cap. Re-run prepare_raw.py with a smaller --sample-pct.")


def load_duckdb(src: Path, path: Path) -> None:
    import duckdb

    path.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(path))
    con.execute("CREATE SCHEMA IF NOT EXISTS raw")
    for name in TABLES:
        con.execute(f"CREATE OR REPLACE TABLE raw.{name} AS SELECT * FROM '{(src / f'{name}.parquet').as_posix()}'")
        n = con.sql(f"SELECT COUNT(*) FROM raw.{name}").fetchone()[0]
        print(f"  raw.{name:20s} {n:>12,d} rows")
    con.close()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", choices=["bigquery", "duckdb"], required=True)
    ap.add_argument("--src", default="data/prepared")
    ap.add_argument("--project", help="GCP project id (bigquery)")
    ap.add_argument("--dataset", default="raw")
    ap.add_argument("--location", default="US")
    ap.add_argument("--duckdb-path", default="warehouse/streampulse.duckdb")
    a = ap.parse_args()
    src = Path(a.src)
    if a.target == "bigquery":
        if not a.project:
            ap.error("--project is required for bigquery")
        load_bigquery(src, a.project, a.dataset, a.location)
    else:
        load_duckdb(src, Path(a.duckdb_path))


if __name__ == "__main__":
    main()
