# MEMO — Reducing subscriber churn at KKBox

**To:** Head of Subscriptions · **From:** Shrey Marwha · **Date:** _date_
**Data:** KKBox members, payments and labels, Jan 2015 – Mar 2017 (complete); listening logs (10% user sample)

---

### Bottom line
_One sentence: what to do and what it is worth. Filled last, from the numbers below._

### What we found
1. **Who churns:** _segment_ churns at _x%_ vs _y%_ overall (_n_ members). — `phase03_retention.json`
2. **What it costs:** churners took _NTD z_ of monthly revenue (_s%_ of the base); _k_ segments hold _t%_ of the loss. — `phase04_revenue_ltv.json`
3. **Why:** _top driver in plain English_ (± _pp_), _second driver_; listening activity _adds / does not add_ predictive value (AUC _a_ → _b_). — `phase05_churn_drivers.json`

### What we recommend
1. _Action targeted at finding 1/3_ — expected impact: _range, with assumption stated_
2. _Action targeted at finding 2_ — expected impact: _…_
3. **Test before rolling out:** run the retention-offer experiment (n = _n per arm_, ~_m_ months) — see design doc.

### Estimated impact
_If the offer cuts churn in the target segment by the break-even effect (_p_ pp), it saves about _NTD v_ per month. ASSUMPTIONS: …_

### Risks and limits
Data is Taiwan 2015–17 · drivers are associations, not causes · listening insights from a 10% sample · _…_

---
_Every number in this memo is taken from `results/*.json`; nothing is estimated by hand._
