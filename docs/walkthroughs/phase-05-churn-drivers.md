# Phase 5 — Churn drivers

## Run
`notebooks/05_churn_drivers.ipynb` → Run All → paste `results/phase05_churn_drivers.json`.
On the full label population the logistic regression takes a few minutes on a laptop.

## Leakage — the single most important idea here

**Leakage** = a feature that contains information you wouldn't have at prediction time. It makes the model
look brilliant in testing and useless in real life.

| Trap in KKBox | Why it leaks | Guard |
|---|---|---|
| A March 2017 renewal or cancel row | it *is* the outcome | only periods starting ≤ 28 Feb 2017 (`mart_churn_features`) |
| `effective_end_date` shortened by a March cancel | encodes the March cancel | `days_to_expiry_at_cutoff` uses the end date *as known at cutoff* |
| Listening in March | behaviour inside the churn window | logs filtered `activity_date ≤ cutoff` |
| Median age / top payment methods learned on all data | test set leaks into preprocessing | `fit_prep()` on train only |

A dbt test (`assert_no_feature_after_cutoff`) and a notebook `assert` both fail if a feature crosses the cutoff.

## Key code

```python
tr, te = train_test_split(d, test_size=0.3, stratify=d.y, random_state=SEED)
prep = fit_prep(tr)
Xtr = drop_unestimable(build_X(tr, prep, with_logs), tr.y)
Xte = build_X(te, prep, with_logs).reindex(columns=Xtr.columns, fill_value=0)
m = sm.Logit(tr.y, sm.add_constant(Xtr)).fit()
ame = m.get_margeff(at="overall", dummy=True).summary_frame()
```

| Line | What it does | Why |
|---|---|---|
| `train_test_split(…, stratify=d.y)` | 70/30 split, same churn rate in both | judge the model on members it never saw |
| `random_state=SEED` | fixed seed | reproducible numbers |
| `fit_prep(tr)` | learns median age + top payment methods on **train only** | no test-set information leaks in |
| `drop_unestimable(…)` | drops categories with < 20 churners or non-churners | with too few cases the coefficient can't be estimated (quasi-separation) |
| `.reindex(columns=Xtr.columns, fill_value=0)` | test gets exactly the train columns | a category missing from test would otherwise crash or misalign |
| `sm.Logit(…)` | logistic regression (statsmodels) | gives p-values and CIs, unlike scikit-learn's default |
| `get_margeff(at="overall", dummy=True)` | average marginal effect | turns coefficients into **percentage-point** changes in churn probability — the language a business uses |

## Reading the output

| Number | Meaning | Say it like (fill `r`, `k`, `X` from the JSON) |
|---|---|---|
| Odds ratio `r` | odds of churning multiply by `r` per unit step (`r` < 1 = protective) | "members with auto-renew on have `r`× the odds of churning" |
| AME `k` pp | churn probability changes by `k` points on average | "auto-renew on is associated with a `k`-point lower churn probability, holding the rest fixed" |
| ROC AUC | chance a random churner is ranked above a random non-churner | 0.5 = coin flip, 1 = perfect |
| PR AUC | precision-recall area | more informative than ROC when churners are a minority |
| Top-decile capture | % of all churners among the 10% the model ranks riskiest | "target 10% of members, reach `X`% of churners" — the business use |

The notebook prints these sentences for you from the real coefficients — copy them, don't paraphrase the numbers.

**Model B vs A on the same members** isolates what listening behaviour adds. If the AUC gain is small,
that's a finding: plan and payment behaviour already explain most churn.

**Decision tree (depth 3)**: a cross-check that finds interactions (e.g. "auto-renew off **and** short tenure")
and reads as rules. If its AUC is far below the logistic model's, the relationships are mostly additive.

## ✅ Checklist
- [ ] No leakage assertion fired
- [ ] Model A AUC and top-decile capture recorded
- [ ] Model B vs A-on-same-members compared (listening value)
- [ ] 3–5 significant drivers translated into plain English — copy them from the notebook output
- [ ] Any driver you'd quote has a sensible sign (if not, look for collinearity before quoting)
- [ ] `phase05_driver_table.csv` exists (feeds Tableau)

## 🎤 Interview questions
| Q | Answer |
|---|---|
| How did you avoid leakage? | "Every feature is dated on or before 28 February; the labels are about March expiries. I caught a subtle one: a March cancellation shortens the membership end date, so I used the end date as known at the cutoff. Preprocessing is fitted on the training set only, and a dbt test fails the build if a feature crosses the cutoff." |
| Why logistic regression and not XGBoost? | "The goal was to explain churn to a business, not win a Kaggle leaderboard. Logistic regression gives effects I can say in a sentence with confidence intervals. I checked a decision tree for interactions; a boosted model could raise accuracy and would be the next step if the goal were targeting." |
| Do your drivers prove what causes churn? | "No. They show who churns, holding other measured factors fixed. Auto-renew users may simply be more committed. To know whether pushing auto-renew reduces churn you need an experiment — which is why Phase 6 designs one." |
