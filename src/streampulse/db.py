"""One query helper for both warehouses.

Notebooks call `query(sql)` and `t("table_name")` and never care whether the data
lives in BigQuery (real run) or a local DuckDB file (laptop / CI test run).

Environment variables (set them in your shell or a .env you never commit):
  STREAMPULSE_TARGET   bigquery | duckdb          (default: bigquery)
  GCP_PROJECT          your BigQuery project id   (bigquery only)
  DBT_DATASET          dbt base dataset           (default: dbt_dev on BigQuery, main on DuckDB)
  DUCKDB_PATH          path to the DuckDB file    (default: warehouse/streampulse.duckdb)
  STREAMPULSE_FIXTURE  1 = running on SYNTHETIC test data -> results go to a quarantined folder
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
TARGET = os.getenv("STREAMPULSE_TARGET", "bigquery").lower()
IS_FIXTURE = os.getenv("STREAMPULSE_FIXTURE", "0") == "1"

# Results from synthetic test data must never be mixed with real results.
RESULTS_DIR = ROOT / "results" / ("_SYNTHETIC_TEST_ONLY" if IS_FIXTURE else "")
RESULTS_DIR.mkdir(parents=True, exist_ok=True)


def banner() -> None:
    """Print where the data comes from at the top of every notebook."""
    if IS_FIXTURE:
        print("!" * 72)
        print("!! SYNTHETIC FIXTURE DATA - for code testing only. Numbers are fake. !!")
        print("!" * 72)
    print(f"target={TARGET}  results -> {RESULTS_DIR.relative_to(ROOT)}")


def _base_dataset() -> str:
    return os.getenv("DBT_DATASET", "dbt_dev" if TARGET == "bigquery" else "main")


def t(model: str, layer: str = "marts") -> str:
    """Fully-qualified name of a dbt model, e.g. t('fct_subscriptions')."""
    schema = f"{_base_dataset()}_{layer}"
    if TARGET == "bigquery":
        project = os.environ["GCP_PROJECT"]
        return f"`{project}.{schema}.{model}`"
    return f"{schema}.{model}"


_duck = None
_bq = None


def query(sql: str) -> pd.DataFrame:
    """Run SQL on the active warehouse and return a DataFrame."""
    global _duck, _bq
    if TARGET == "duckdb":
        import duckdb

        if _duck is None:
            path = os.getenv("DUCKDB_PATH", str(ROOT / "warehouse" / "streampulse.duckdb"))
            _duck = duckdb.connect(path, read_only=True)
        return _duck.sql(sql).df()

    from google.cloud import bigquery

    if _bq is None:
        _bq = bigquery.Client(project=os.environ["GCP_PROJECT"])
    job = _bq.query(sql)
    try:  # Storage Read API is much faster for big pulls; fall back if unavailable
        return job.to_dataframe(create_bqstorage_client=True)
    except Exception:  # noqa: BLE001
        return job.to_dataframe(create_bqstorage_client=False)


def save_result(name: str, payload: dict) -> Path:
    """Write key numbers to results/<name>.json so they can be quoted later.

    Every number in the README, memo and resume must come from one of these files.
    """
    payload = {"_source": "SYNTHETIC_FIXTURE" if IS_FIXTURE else "REAL_DATA", **payload}
    path = RESULTS_DIR / f"{name}.json"
    path.write_text(json.dumps(payload, indent=2, default=str))
    print(f"saved -> {path.relative_to(ROOT)}")
    return path
