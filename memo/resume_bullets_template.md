# Resume bullets — fill ONLY from results/*.json after the real-data run

Rule: if a number isn't in a results file, it doesn't go on the resume. Keep the file name next to each
number until the bullet is final, so you can answer "where did that number come from?".

**StreamPulse: Subscription Churn & Revenue Analytics** | BigQuery, dbt, SQL, Python, Tableau

- Built a BigQuery + dbt warehouse (staging → marts, _N_ dbt tests, CI on GitHub Actions) over _rows_ KKBox
  payment records and a deterministic 10% user sample of listening logs; resolved _k_ data-quality issues
  (_duplicates_, _invalid expiry dates_) — `mart_data_quality`, `sampling_report.json`
- Ran cohort and segment analysis showing _segment_ churns at _x×_ the average and that _k_ segments drive
  _t%_ of the _NTD z_ monthly revenue lost to churn — `phase03`, `phase04`
- Modelled churn drivers with leakage-safe logistic regression (ROC AUC _a_, top decile captures _c%_ of
  churners) and translated coefficients into _n_ plain-English actions; designed a powered retention-offer
  experiment (n = _n_/arm) — `phase05`, `phase06`
- Analysed a real 90,189-player mobile-game A/B test: flagged a sample-ratio mismatch (p = 0.009) and found
  the treatment cut 7-day retention by 0.82 pp (95% CI 0.31–1.33, p = 0.002) → recommended not shipping — `phase07`
