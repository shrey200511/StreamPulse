"""Phase 1a — turn the Kaggle CSVs into typed Parquet files, sampling user_logs by USER.

Why this step exists
--------------------
* The BigQuery sandbox caps storage at 10 GB. KKBox's user_logs is far bigger,
  so it cannot be loaded whole. members / transactions / labels are small enough
  and are kept in full.
* We sample USERS, not ROWS. A random 10% of rows would give every user a random
  10% of their listening days, which destroys per-user features ("days active in
  the last 30 days"). A 10% sample of users keeps every log row for those users.
* The sample is deterministic: a user is in the sample if
      int(first 8 hex chars of md5(msno), 16) % 100 < SAMPLE_PCT
  Same input -> same sample, on any machine, forever. You can reproduce the same
  bucket in BigQuery with:
      MOD(CAST(CONCAT('0x', SUBSTR(TO_HEX(MD5(msno)), 1, 8)) AS INT64), 100)
* DuckDB streams the CSVs from disk, so a 30 GB file never has to fit in RAM.

Inputs (extracted from the Kaggle .7z files into --raw-dir):
  members_v3.csv, transactions.csv, transactions_v2.csv, train_v2.csv,
  user_logs.csv, user_logs_v2.csv
Outputs (--out-dir): members / transactions / churn_labels / log_sample_frame /
  user_logs .parquet, plus sampling_report.json with the numbers for docs/sampling.md

Usage:
  python scripts/prepare_raw.py --raw-dir data/raw --out-dir data/prepared --sample-pct 10
"""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import duckdb

CSV_SCHEMAS = {
    "members": {"msno": "VARCHAR", "city": "BIGINT", "bd": "BIGINT", "gender": "VARCHAR",
                "registered_via": "BIGINT", "registration_init_time": "BIGINT"},
    "transactions": {"msno": "VARCHAR", "payment_method_id": "BIGINT", "payment_plan_days": "BIGINT",
                     "plan_list_price": "BIGINT", "actual_amount_paid": "BIGINT", "is_auto_renew": "BIGINT",
                     "transaction_date": "BIGINT", "membership_expire_date": "BIGINT", "is_cancel": "BIGINT"},
    "labels": {"msno": "VARCHAR", "is_churn": "BIGINT"},
    "logs": {"msno": "VARCHAR", "date": "BIGINT", "num_25": "BIGINT", "num_50": "BIGINT", "num_75": "BIGINT",
             "num_985": "BIGINT", "num_100": "BIGINT", "num_unq": "BIGINT", "total_secs": "DOUBLE"},
}


def read_csv(path: Path, schema: str) -> str:
    """SQL snippet that reads a CSV with an explicit schema (no type guessing)."""
    cols = ", ".join(f"'{k}': '{v}'" for k, v in CSV_SCHEMAS[schema].items())
    return f"read_csv('{path.as_posix()}', header=true, columns={{{cols}}})"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw-dir", default="data/raw")
    ap.add_argument("--out-dir", default="data/prepared")
    ap.add_argument("--sample-pct", type=int, default=10, help="percent of USERS whose logs are kept (1-100)")
    ap.add_argument("--memory-limit", default="4GB", help="DuckDB RAM cap; lower it on an 8 GB laptop")
    ap.add_argument("--skip-counts", action="store_true", help="skip the full-log row counts (saves one scan)")
    a = ap.parse_args()
    assert 1 <= a.sample_pct <= 100
    raw, out = Path(a.raw_dir), Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect()
    con.execute(f"SET memory_limit='{a.memory_limit}'")
    con.execute(f"SET temp_directory='{(out / '_duckdb_tmp').as_posix()}'")
    t0 = time.time()

    def copy(sql: str, name: str) -> int:
        con.execute(f"COPY ({sql}) TO '{(out / name).as_posix()}' (FORMAT PARQUET, COMPRESSION ZSTD)")
        n = con.sql(f"SELECT COUNT(*) FROM '{(out / name).as_posix()}'").fetchall()[0][0]
        print(f"  {name:28s} {n:>14,d} rows   ({time.time() - t0:,.0f}s)")
        return n

    print("Writing full tables ...")
    report: dict = {"sample_pct": a.sample_pct, "rows": {}}
    report["rows"]["members"] = copy(f"SELECT * FROM {read_csv(raw / 'members_v3.csv', 'members')}", "members.parquet")
    # v1 + v2 transactions are unioned as-is; duplicates are removed later in dbt, visibly and tested
    report["rows"]["transactions"] = copy(
        f"SELECT *, 'transactions' AS source_file FROM {read_csv(raw / 'transactions.csv', 'transactions')} "
        f"UNION ALL SELECT *, 'transactions_v2' FROM {read_csv(raw / 'transactions_v2.csv', 'transactions')}",
        "transactions.parquet")
    report["rows"]["churn_labels"] = copy(f"SELECT * FROM {read_csv(raw / 'train_v2.csv', 'labels')}",
                                          "churn_labels.parquet")

    print("Building the user sampling frame ...")
    # Every user we know of, from every small table. Logs are then filtered to sampled users.
    copy(f"""
        WITH users AS (
            SELECT msno FROM '{(out / 'members.parquet').as_posix()}'
            UNION SELECT msno FROM '{(out / 'transactions.parquet').as_posix()}'
            UNION SELECT msno FROM '{(out / 'churn_labels.parquet').as_posix()}'
        )
        SELECT msno,
               CAST(('0x' || substr(md5(msno), 1, 8))::UBIGINT % 100 AS INTEGER) AS sample_bucket,
               CAST(('0x' || substr(md5(msno), 1, 8))::UBIGINT % 100 AS INTEGER) < {a.sample_pct} AS in_log_sample
        FROM users""", "log_sample_frame.parquet")

    frame = f"'{(out / 'log_sample_frame.parquet').as_posix()}'"
    logs = (f"SELECT *, 'user_logs' AS source_file FROM {read_csv(raw / 'user_logs.csv', 'logs')} "
            f"UNION ALL SELECT *, 'user_logs_v2' FROM {read_csv(raw / 'user_logs_v2.csv', 'logs')}")

    if not a.skip_counts:
        print("Counting full user_logs (one full scan) ...")
        r = con.sql(f"""
            SELECT COUNT(*) AS rows_total,
                   COUNT(DISTINCT l.msno) AS users_total,
                   SUM(CASE WHEN f.in_log_sample THEN 1 ELSE 0 END) AS rows_in_sample
            FROM ({logs}) l LEFT JOIN {frame} f USING (msno)""").fetchall()[0]
        report["user_logs_full"] = {"rows": r[0], "users": r[1], "rows_in_sample": r[2]}
        print(f"  full logs: {r[0]:,} rows, {r[1]:,} users; sampled rows: {r[2]:,}")

    print(f"Writing sampled user_logs ({a.sample_pct}% of users) ...")
    report["rows"]["user_logs_sampled"] = copy(
        f"SELECT l.* FROM ({logs}) l SEMI JOIN (SELECT msno FROM {frame} WHERE in_log_sample) s USING (msno)",
        "user_logs.parquet")

    # Representativeness check: is the churn rate in the sample close to the population's?
    lab = f"'{(out / 'churn_labels.parquet').as_posix()}'"
    r = con.sql(f"""
        SELECT COUNT(*) AS n, AVG(is_churn) AS churn_rate,
               SUM(CASE WHEN f.in_log_sample THEN 1 ELSE 0 END) AS n_sample,
               AVG(CASE WHEN f.in_log_sample THEN is_churn END) AS churn_rate_sample
        FROM {lab} l LEFT JOIN {frame} f USING (msno)""").fetchall()[0]
    report["label_population"] = {"users": r[0], "churn_rate": r[1],
                                  "users_in_log_sample": r[2], "churn_rate_in_log_sample": r[3]}
    report["parquet_mb"] = {p.name: round(p.stat().st_size / 1e6, 1) for p in out.glob("*.parquet")}
    (out / "sampling_report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    print(f"Done in {time.time() - t0:,.0f}s -> {out}/sampling_report.json")


if __name__ == "__main__":
    main()
