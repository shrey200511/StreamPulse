# Phase 0 — Setup

## Run (Windows PowerShell; Mac/Linux: `source .venv/bin/activate`)

```powershell
git clone https://github.com/shrey200511/streampulse.git
cd streampulse
python -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r requirements.txt
python scripts/smoke_test.py          # proves everything works before touching real data
```

Then BigQuery:

```powershell
gcloud init
gcloud auth application-default login
bq mk --location=US --dataset YOUR_PROJECT_ID:raw
mkdir $HOME\.dbt -Force
copy dbt\streampulse\profiles.example.yml $HOME\.dbt\profiles.yml   # then edit YOUR_PROJECT_ID
cd dbt\streampulse; dbt debug --target bigquery; cd ..\..
```

| Line | What it does | Why |
|---|---|---|
| `python -m venv .venv` | isolated Python | dbt pins many packages; keep them away from other projects |
| `pip install -r requirements.txt` | installs pinned dbt v1 + adapters + analysis libs | pins = same versions as CI; dbt v2 exists but this project targets Core v1 |
| `python scripts/smoke_test.py` | runs the whole pipeline on synthetic data with DuckDB | if this passes, any later failure is about data/credentials, not code |
| `gcloud auth application-default login` | OAuth credentials on your laptop | no service-account key file that could leak to GitHub |
| `bq mk --location=US …:raw` | creates the raw dataset | all datasets must share one region or BigQuery can't join them |
| copy `profiles.example.yml` | dbt connection config outside the repo | credentials never committed (`profiles.yml` is in `.gitignore`) |
| `dbt debug --target bigquery` | tests the connection | expect "All checks passed!" |

Profile has two targets: `bigquery` (real) and `duckdb` (local/CI). Every dbt command takes `--target`.

## ✅ Checklist
- [ ] `python scripts/smoke_test.py` ends with **SMOKE TEST PASSED**
- [ ] `dbt debug --target bigquery` → All checks passed
- [ ] `raw` dataset exists in **US**
- [ ] Nothing in `git status` under `data/`, `warehouse/`, or any `profiles.yml`

## 🎤 Interview questions
| Q | Answer |
|---|---|
| Why does the dbt project run on two databases? | "BigQuery holds the real data. The same models also run on DuckDB against a small synthetic dataset, so GitHub Actions tests every model and notebook on every push without cloud credentials. I wrote a few cross-database macros (date parsing, month spine) to make that work." |
| How did you handle credentials? | "OAuth via gcloud — no key file. `profiles.yml` lives in my home folder, and the repo's `.gitignore` blocks credentials and data." |
| Why pin versions? | "So my laptop, CI and anyone reproducing it run identical code. dbt released v2 recently; pinning to v1 avoids silent behaviour changes." |
