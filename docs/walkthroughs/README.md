# Walkthroughs — run it, understand it, defend it

One file per phase. Each has: what to run · the key code explained line by line · a checklist to confirm
before moving on · three interview questions with answers.

| Phase | File | Runs on | Real numbers? |
|---|---|---|---|
| 0 | [phase-00-setup.md](phase-00-setup.md) | laptop | — |
| 1 | [phase-01-warehouse.md](phase-01-warehouse.md) | laptop → BigQuery | sampling report |
| 2 | [phase-02-dbt.md](phase-02-dbt.md) | BigQuery | data-quality counts |
| 3 | [phase-03-retention.md](phase-03-retention.md) | notebook 03 | yes |
| 4 | [phase-04-revenue-ltv.md](phase-04-revenue-ltv.md) | notebook 04 | yes |
| 5 | [phase-05-churn-drivers.md](phase-05-churn-drivers.md) | notebook 05 | yes |
| 6 | [phase-06-experiment-design.md](phase-06-experiment-design.md) | notebook 06 | baseline only — **design** |
| 7 | [phase-07-ab-test.md](phase-07-ab-test.md) | notebook 07 | **done — real Cookie Cats results** |
| 8 | [phase-08-forecast.md](phase-08-forecast.md) | notebook 08 | yes |
| 9 | [phase-09-dashboard.md](phase-09-dashboard.md) | Tableau Public | yes |
| 10 | [phase-10-memo.md](phase-10-memo.md) | memo + resume | yes |

**Golden rule:** a number goes into the README, dashboard, memo or resume only if it is in a
`results/*.json` file produced from real data. Synthetic test output lives in
`results/_SYNTHETIC_TEST_ONLY/` and is never quoted.
