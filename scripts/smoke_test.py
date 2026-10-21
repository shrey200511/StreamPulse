"""End-to-end test of the whole pipeline on SYNTHETIC data, with no downloads and no cloud.

fixture -> prepare_raw -> DuckDB raw -> dbt build (all models + tests) -> notebooks 03-06, 08
-> Tableau export. Runs on Windows, macOS, Linux and in GitHub Actions.

Every output lands in git-ignored folders (warehouse/, results/_SYNTHETIC_TEST_ONLY/).
Phase 7 is skipped: it uses the real Cookie Cats file, which is not in the repo.

Usage:  python scripts/smoke_test.py
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / "tests" / "fixtures" / "generated"
DB = ROOT / "warehouse" / "smoke_test.duckdb"
PROFILES = ROOT / "warehouse" / "_profiles"
NOTEBOOKS = ["03_retention_cohorts", "04_revenue_ltv", "05_churn_drivers", "06_experiment_design", "08_forecast"]


def run(cmd: list[str], cwd: Path = ROOT, env: dict | None = None) -> None:
    print("\n$", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=cwd, env=env, check=True)


def main() -> None:
    env = {**os.environ, "STREAMPULSE_TARGET": "duckdb", "STREAMPULSE_FIXTURE": "1",
           "DUCKDB_PATH": str(DB), "DBT_PROFILES_DIR": str(PROFILES)}
    py = sys.executable

    if DB.exists():
        DB.unlink()
    PROFILES.mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / "dbt" / "streampulse" / "profiles.example.yml", PROFILES / "profiles.yml")

    run([py, "scripts/make_fixture.py", "--out", str(FIX)])
    run([py, "scripts/prepare_raw.py", "--raw-dir", str(FIX), "--out-dir", str(FIX / "prepared"), "--sample-pct", "50"])
    run([py, "scripts/load_warehouse.py", "--target", "duckdb", "--src", str(FIX / "prepared"), "--duckdb-path", str(DB)])
    run(["dbt", "build", "--target", "duckdb"], cwd=ROOT / "dbt" / "streampulse", env=env)

    out = ROOT / "results" / "_SYNTHETIC_TEST_ONLY" / "executed_notebooks"
    out.mkdir(parents=True, exist_ok=True)
    for nb in NOTEBOOKS:
        run([py, "-m", "jupyter", "nbconvert", "--to", "notebook", "--execute", f"notebooks/{nb}.ipynb",
             "--output-dir", str(out), "--ExecutePreprocessor.timeout=900"], env=env)
    run([py, "scripts/export_for_tableau.py"], env=env)
    print("\nSMOKE TEST PASSED (synthetic data - numbers are meaningless)")


if __name__ == "__main__":
    main()
