# Phase 10 — Recommendation memo + resume bullets

## Run
Once `results/phase03…08_*.json` exist from the real run:
1. Fill [`memo/memo_template.md`](../../memo/memo_template.md) — every number from a results file.
2. Export to PDF (open in Word / Google Docs → Download as PDF, or `pandoc memo.md -o memo.pdf`). One page.
3. Fill [`memo/resume_bullets_template.md`](../../memo/resume_bullets_template.md); keep 3–4 bullets.
4. Update the README "Key findings" table.

## Consulting memo structure (pyramid principle)

| Section | Rule |
|---|---|
| Bottom line first | the decision and its value, in one sentence — the reader may stop here |
| 3 findings | each: number + comparison + source. "X churns at 2.1× the average (n = …)" beats "X churns a lot" |
| 3 recommendations | each tied to a finding; verbs first ("Default new monthly buyers into auto-renew") |
| Impact | a range with the assumption written next to it |
| Risks | data limits + what could make the recommendation wrong |

## ✅ Checklist
- [ ] Every number traceable to a `results/*.json` key
- [ ] Assumptions labelled; sampled numbers labelled; design-only experiment labelled
- [ ] Fits on one page
- [ ] Resume bullets: action verb + method + **real** number + business outcome
- [ ] README findings filled

## 🎤 Interview questions
| Q | Answer |
|---|---|
| Walk me through your recommendation. | Answer with the memo's bottom line, then the one finding that drives it, then the experiment that would confirm it. 60 seconds. |
| How confident are you in the impact estimate? | "It's a range resting on stated assumptions — mainly that saved members behave like current ones. That's exactly why the first recommendation is a controlled test before a full rollout." |
| What would you do with more time / data? | "Out-of-time validation with a second label month, revenue-weighted targeting, a boosted model for ranking, and longer-term retention outcomes for the Cookie Cats SRM investigation." |
