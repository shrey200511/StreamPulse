# Phase 6 — Experiment design (DESIGN ONLY)

> ⚠️ KKBox ran no experiment. This phase uses real data only for the **baseline churn rate** and
> **eligible volume**. Everything else is a design choice or an assumption.

## Run
1. After Phases 3–5, confirm the target segment in the parameter cell (`SEGMENT_SQL`). Default: monthly plan, auto-renew off.
2. Run `notebooks/06_experiment_design.ipynb` → paste `results/phase06_experiment_design.json`.
3. Fill the tables in [`docs/experiment_design.md`](../experiment_design.md).

## Key code — sample size

```python
h = proportion_effectsize(p0, p0 - mde)
n = NormalIndPower().solve_power(effect_size=h, alpha=0.05, power=0.80, ratio=1.0, alternative="two-sided")
months = 2 * n / (eligible * SHARE_ENROLLED)
```

| Line | What it does | Why |
|---|---|---|
| `p0` | baseline churn in the segment (real) | the starting point; power depends heavily on it |
| `mde` | minimum detectable effect — the smallest change worth detecting | a **business** choice: smaller MDE → much bigger sample (n ∝ 1/MDE²) |
| `proportion_effectsize` | Cohen's h = 2·asin√p₁ − 2·asin√p₀ | puts differences between proportions on one scale |
| `alpha=0.05` | 5% false-positive risk | convention; two-sided so harm is detected too |
| `power=0.80` | 80% chance to detect a true effect of size MDE | convention; 20% risk of missing it |
| `ratio=1.0` | equal arms | most power for a fixed total |
| `months = 2n / eligible` | time to enrol both arms | eligible = memberships expiring per month in the segment |

## Key code — break-even effect

| Quantity | Formula | Status |
|---|---|---|
| Offer cost per treated member | discount share × price | **ASSUMPTION** (50% off one month) |
| Value of one saved member | price × 1/churn | **ASSUMPTION** (constant churn) |
| Break-even reduction | cost ÷ value | if MDE > this, a "significant win" can still lose money |

## ✅ Checklist
- [ ] Segment chosen with a reason from Phases 3–5 (high churn **and** meaningful revenue at risk)
- [ ] Sample-size table and duration filled into `docs/experiment_design.md`
- [ ] MDE chosen ≤ break-even effect, or the trade-off is stated
- [ ] "DESIGN ONLY" label visible in the doc, the notebook and the dashboard (if shown)

## 🎤 Interview questions
| Q | Answer |
|---|---|
| How did you choose the minimum detectable effect? | "From the business side: the offer costs money on everyone treated, so I computed the break-even churn reduction. The test needs to detect at least that, otherwise a statistically significant result could still be unprofitable. Then the power analysis gives the sample size." |
| What are your guardrail metrics? | "Net revenue per eligible member including the offer cost, churn one month after the discounted month — to catch 'we only delayed churn' — and the sample ratio, to catch broken assignment." |
| Why not just give the offer to everyone predicted to churn? | "Because the model finds who churns, not who an offer would save. Some would renew anyway — the discount is wasted on them — and some leave regardless. Only a randomised control group measures the incremental effect." |
