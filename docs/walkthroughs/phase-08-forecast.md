# Phase 8 — Forecast

## Run
`notebooks/08_forecast.ipynb` → Run All → paste `results/phase08_forecast.json`.

## Design

| Series | Grain | Baseline(s) | Model | Holdout |
|---|---|---|---|---|
| Active subscribers | monthly (month-end) | naive, drift | Holt, damped additive trend (ETS) | last 3 months |
| Revenue | daily → summed to the quarter | seasonal naive (same weekday last week) | Holt-Winters: damped trend + **weekly** seasonality | last 90 days |

**Why no yearly seasonality on the monthly series?** After dropping 6 warm-up months there are fewer than
24 training months. Learning a 12-month pattern needs at least two full cycles. The notebook checks this and
says so instead of fitting a model that would just memorise noise. Daily revenue has hundreds of points and a
real weekly/billing rhythm, so that's where the seasonal model belongs.

## Key code

```python
train, test = s.iloc[:-3], s.iloc[-3:]
fc["naive"] = np.repeat(train.iloc[-1], 3)
fc["drift"] = train.iloc[-1] + slope * np.arange(1, 4)
holt = ETSModel(train, error="add", trend="add", damped_trend=True).fit()
...
ExponentialSmoothing(dtrain, trend="add", damped_trend=True, seasonal="add", seasonal_periods=7).fit()
```

| Line | What it does | Why |
|---|---|---|
| `s.iloc[:-3]`, `s.iloc[-3:]` | time-ordered holdout | never shuffle a time series — the test must be the future |
| naive | "next month = this month" | the bar to beat; surprisingly hard |
| drift | straight line from first to last point | simple trend baseline |
| `ETSModel(… trend="add", damped_trend=True)` | exponential smoothing with a trend that flattens | undamped trends over-extrapolate; damping is safer for planning |
| `seasonal="add", seasonal_periods=7` | learns a repeating weekly shape | daily revenue depends on weekday and billing cycles |
| MAE / MAPE | average absolute error, and as % of actual | MAPE is easy to explain; MAE doesn't explode near zero |
| refit on all data, then forecast | uses the latest months too | holdout is for choosing a model, not for the final forecast |
| `get_prediction(...).summary_frame()` | forecast with a 95% interval | a single number hides uncertainty |

## ✅ Checklist
- [ ] Best model beats naive on the holdout — if not, report naive and say so
- [ ] Holdout MAPE / quarter error recorded
- [ ] Next-quarter forecast + interval recorded for the dashboard
- [ ] Limitation noted: data ends Mar 2017, so "next quarter" = Apr–Jun 2017

## 🎤 Interview questions
| Q | Answer |
|---|---|
| How did you validate the forecast? | "Time-based holdout: trained on everything except the last 3 months (90 days for revenue), forecast those, measured MAE and MAPE, and compared against naive and drift baselines. Then refitted on all data for the real forecast." |
| Why didn't you use a fancier model like Prophet or SARIMA? | "With ~2 years of monthly data, extra complexity mostly fits noise. I first checked whether a model beats naive at all. For yearly seasonality I didn't have two full cycles, so I modelled weekly seasonality on daily revenue where the data supports it." |
| How would the business use this? | "As a planning range, not a point. The interval tells finance the realistic band for next quarter's subscribers; the holdout error says how much to trust it." |
