"""Phase 9 — export the marts Tableau Public needs as small CSVs.

Tableau Public cannot keep a live BigQuery connection in a published workbook, so the
dashboard is built on these extracts. They are aggregated tables (a few hundred to a few
thousand rows each), safe to commit to GitHub — no member-level data.

Synthetic-fixture runs write to results/_SYNTHETIC_TEST_ONLY/tableau/ instead, so fake
numbers can never end up in dashboard/data/.

Usage:  python scripts/export_for_tableau.py
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import pandas as pd  # noqa: E402

from streampulse.db import IS_FIXTURE, RESULTS_DIR, query, t  # noqa: E402

OUT = (RESULTS_DIR / "tableau") if IS_FIXTURE else (ROOT / "dashboard" / "data")
OUT.mkdir(parents=True, exist_ok=True)

EXPORTS = {
    # file name            : SQL (aggregated marts only)
    "monthly_kpis":          f"select * from {t('mart_monthly_kpis')} order by month_start",
    "cohort_retention":      f"select * from {t('mart_cohort_retention')} where months_since_signup <= 24",
    "churn_by_segment":      f"select * from {t('mart_churn_by_segment')}",
    "value_at_risk":         f"select * from {t('mart_value_at_risk')} order by value_at_risk_rank",
    "ltv_by_segment":        f"select * from {t('mart_ltv_by_segment')}",
    "data_quality":          f"select * from {t('mart_data_quality')}",
}


def main() -> None:
    for name, sql in EXPORTS.items():
        df = query(sql)
        df.to_csv(OUT / f"{name}.csv", index=False)
        print(f"  {name:20s} {len(df):>7,d} rows -> {OUT / (name + '.csv')}")

    # Phase 5 driver table and Phase 8 forecast come from the notebooks' saved results.
    drivers = RESULTS_DIR / "phase05_driver_table.csv"
    if drivers.exists():
        shutil.copy(drivers, OUT / "churn_drivers.csv")
        print(f"  churn_drivers         copied from {drivers.name}")
    fc_path = RESULTS_DIR / "phase08_forecast.json"
    if fc_path.exists():
        fc = json.loads(fc_path.read_text())["subscribers"]["next_quarter"]
        pd.DataFrame([{"month_start": k, **v} for k, v in fc.items()]).to_csv(OUT / "subscriber_forecast.csv", index=False)
        print("  subscriber_forecast   from phase08_forecast.json")
    if IS_FIXTURE:
        print("SYNTHETIC run: exports quarantined in", OUT)


if __name__ == "__main__":
    main()
