# Experiment design: retention offer for at-risk KKBox members

> ⚠️ **DESIGN ONLY — KKBox never ran this test.** The baseline churn rate and eligible volume come from
> the real data (`results/phase06_experiment_design.json`). Effect sizes are *targets*, offer costs are
> *assumptions*. No outcome in this document is a result.

## 1. Problem
Phases 3–5 identify who churns most and where the revenue loss concentrates. They can't say whether an
intervention would *reduce* churn — members who look similar may differ in ways the data can't see. A
randomised test is the only clean way to measure that.

## 2. Hypothesis
> Offering members on **monthly plans with auto-renew off** a discount on their next month, shown a few days
> before expiry, **reduces the share who churn** (no new subscription within 30 days of expiry).

* H0: churn(treatment) = churn(control)
* H1: churn(treatment) ≠ churn(control) — two-sided, so a harmful offer is also detected

## 3. Design

| Element | Choice | Why |
|---|---|---|
| Unit of randomisation | member | the decision (renew or not) is per member; avoids one member seeing both |
| Eligibility | monthly plan, auto-renew off, membership expiring in the test window | highest-risk segment that must actively re-buy (from Phase 3) |
| Split | 50 / 50, random at eligibility | maximises power for a fixed sample |
| Treatment | offer of `OFFER_DISCOUNT_SHARE` off next month (ASSUMPTION: 50%), shown 3 days before expiry | |
| Control | business as usual | |
| Exposure logging | log assignment *and* whether the offer was actually shown | needed for SRM checks and intent-to-treat analysis |

## 4. Metrics

| Type | Metric | Direction |
|---|---|---|
| **Primary** | 30-day churn rate after expiry (KKBox definition) | ↓ |
| Secondary | share switching auto-renew on | ↑ |
| Secondary | listening days in the 30 days after expiry | ↑ |
| **Guardrail** | net revenue per eligible member over 90 days (offer cost included) | must not fall |
| **Guardrail** | churn in the month *after* the discounted month (did we just delay churn?) | must not rise |
| **Guardrail** | sample ratio (assignment counts) | 50/50, chi-square p ≥ 0.01 |

## 5. Sample size and duration
From `notebooks/06_experiment_design.ipynb` (α = 0.05 two-sided, power = 0.80):

| Minimum detectable effect (absolute) | n per arm | Months of expiries needed |
|---|---|---|
| _fill from results/phase06_experiment_design.json → sample_size_table_ | | |

**Baseline churn in the segment:** _fill_ · **Eligible members per month:** _fill_

**Choosing the MDE:** it must be no larger than the **break-even effect** (_fill: ASSUMPTION_breakeven_abs_reduction_),
otherwise a statistically significant win could still lose money. Duration is rounded **up to whole weeks**
so every weekday is represented equally, with a minimum of 2 full billing cycles.

## 6. Analysis plan (fixed before launch)
1. SRM check first; stop and debug if p < 0.01.
2. Intent-to-treat: compare everyone *assigned*, not only those who saw the offer.
3. Two-proportion z-test on churn; report the difference with a 95% CI, not just the p-value.
4. Guardrails: revenue per eligible member (with offer cost), and churn one month later.
5. No peeking: one analysis at the planned end date. (If early looks are needed, use a sequential method decided in advance.)
6. Segment cuts (price band, tenure) are exploratory only.

## 7. Decision rule
* **Ship** if churn falls significantly **and** the CI for net revenue per member excludes a loss.
* **Iterate** (smaller discount, different timing) if churn falls but revenue does not hold up.
* **Don't ship** if churn does not fall, or a guardrail is breached.

## 8. Risks
Discount anchoring (members wait for offers) · cannibalising members who would have renewed anyway (the
control arm measures this) · novelty effect · interference if members share accounts.
