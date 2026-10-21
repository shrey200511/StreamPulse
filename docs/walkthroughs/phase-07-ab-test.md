# Phase 7 — Real A/B test: Cookie Cats ✅ completed

## The test
Cookie Cats is a mobile puzzle game by Tactile Entertainment. At install, players were randomly given the
first progress "gate" at level 30 (`gate_30`, control) or level 40 (`gate_40`, treatment). The dataset
(DataCamp project; also on Kaggle as *Mobile Games A/B Testing – Cookie Cats*) has one row per player:
1-day and 7-day retention and rounds played in the first 14 days.

**Why this dataset:** real experiment groups and real outcomes, a retention metric (matches the KKBox
theme), and an actual SRM problem to handle.

## Run / verify
Download `cookie_cats.csv` from Kaggle into `data/raw/`, run `notebooks/07_cookie_cats_ab_test.ipynb`.
The notebook checks 90,189 rows and prints the file's SHA-256. The committed results used a file with
SHA-256 `5ab54d76…c46bd`; if yours matches, the numbers below will match.

## Results (from `results/phase07_ab_test.json`)

| Check | gate_30 | gate_40 | Difference | Test |
|---|---|---|---|---|
| Players | 44,700 (49.56%) | 45,489 (50.44%) | — | **SRM: χ² = 6.90, p = 0.0086 → mismatch at the 0.01 level** |
| 1-day retention | 44.82% | 44.23% | −0.59 pp (95% CI −1.24 to +0.06) | z = 1.78, p = 0.074 → not significant |
| **7-day retention (primary)** | **19.02%** | **18.20%** | **−0.82 pp (95% CI −1.33 to −0.31)**, −4.3% relative | **z = 3.16, p = 0.0016** |
| 7-day, bootstrap (5,000 resamples) | | | 95% CI −1.33 to −0.32 pp | 99.9% of resamples show gate_40 lower |
| Rounds played (median) | 17 | 16 | | Mann-Whitney p = 0.050 (borderline) |

Effect size: Cohen's h = −0.021 — small per player, but retention compounds into revenue across a large player base.

## Recommendation
**Don't ship gate_40 — keep the gate at level 30.** Seven-day retention, the metric closest to long-term
value, is significantly lower with the later gate, and the bootstrap agrees with the z-test.

**Caveats, in order of importance**
1. **Sample ratio mismatch.** With 50/50 assignment, a 45,489 / 44,700 split this uneven would happen by
   chance less than 1% of the time. Something in assignment or logging may be off (e.g. one version dropping
   some installs). Before relying on the *size* of the effect, find the cause. Not shipping is still the
   safe call: SRM weakens the evidence for change, and the status quo needs no evidence.
2. Retention is not revenue — in-app purchases aren't in the data.
3. Only 1- and 7-day horizons; longer-term effects are unknown.
4. Possible novelty effects; one game, one period.

## Key code — SRM and the z-test

```python
chi2, srm_p = stats.chisquare(counts.values, expected)
z, pval = proportions_ztest(x, n)
se = np.sqrt(p0*(1-p0)/n0 + p1*(1-p1)/n1)
ci = (diff - 1.96*se, diff + 1.96*se)
```

| Line | What it does | Why |
|---|---|---|
| `chisquare(observed, expected)` | compares group sizes with an exact 50/50 | SRM check **first** — if assignment is broken, every other number is suspect |
| `proportions_ztest(x, n)` | tests H0: same retention in both groups | standard test for two proportions with large n |
| `se = sqrt(p(1-p)/n + …)` | standard error of the difference | uncertainty of the gap |
| `diff ± 1.96·se` | 95% CI for the difference | tells the *size* of the effect, not just whether it exists |
| bootstrap loop | resample players with replacement 5,000× | checks the result without assuming normality |
| Mann-Whitney U | compares rounds distributions | rounds are very skewed (one player: 49,854 rounds) — means and t-tests are fragile |

## ✅ Checklist
- [x] SRM checked first and reported
- [x] Primary metric chosen before looking (7-day retention)
- [x] Difference with CI, p-value, effect size, bootstrap
- [x] Skewed metric handled with a rank test; extreme player reported, not silently dropped
- [x] Ship / don't-ship with caveats
- [ ] Re-run on your own Kaggle download and confirm the SHA-256 / numbers match

## 🎤 Interview questions
| Q | Answer |
|---|---|
| What is SRM and what did you do about it? | "Sample ratio mismatch: the groups are more unequal than random assignment allows. Here 45,489 vs 44,700, chi-square p = 0.009. It usually means a bug in assignment or logging. I reported it, kept the recommendation conservative — don't ship — and would ask engineering to find the cause before trusting the effect size." |
| 1-day retention wasn't significant but 7-day was. Which wins? | "The one chosen before looking. 7-day retention is the primary metric because it's closer to long-term engagement and revenue. 1-day was secondary. Picking whichever came out significant afterwards would be p-hacking." |
| The effect is under one point. Does it matter? | "Relative to a 19% base it's a 4.3% drop in week-one retention. Across millions of installs that's a lot of players lost before they could spend. And the CI excludes zero, so it's unlikely to be noise." |
