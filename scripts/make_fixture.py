"""Generate a SMALL, SYNTHETIC, KKBox-shaped dataset for testing the code.

!!! THIS DATA IS FAKE. It exists only so the pipeline can be tested on a laptop
!!! and in GitHub Actions without downloading 30+ GB from Kaggle. No number
!!! produced from it may appear in the README, dashboard, memo or resume.

It mimics the real files' names, columns and types, and deliberately includes
the kinds of dirt the real data has (duplicates, impossible expiry dates,
junk ages, negative listening seconds, users missing from members), so the
cleaning logic actually gets exercised.

Usage:  python scripts/make_fixture.py --out tests/fixtures/generated --users 4000
"""
from __future__ import annotations

import argparse
import string
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

SIM_START = date(2014, 1, 1)      # simulate before the data window so 2015 has "existing" users
DATA_START = date(2015, 1, 1)     # first day visible in the output, like the real data
V1_END = date(2017, 2, 28)        # transactions.csv / user_logs.csv end here
DATA_END = date(2017, 3, 31)      # *_v2 files cover March 2017
SIM_END = date(2017, 5, 31)       # simulate past the end so churn labels can be computed
LOG_START = date(2016, 10, 1)     # keep the fixture small: logs only for the last 6 months

PLANS = [  # (days, list_price, weight)
    (30, 149, 0.62), (30, 99, 0.10), (30, 129, 0.08), (7, 0, 0.04),
    (90, 447, 0.06), (180, 894, 0.05), (410, 1788, 0.05),
]
PAYMENT_METHODS = [41, 40, 39, 38, 36, 34, 32, 30]


def d2i(d: date) -> int:
    return d.year * 10000 + d.month * 100 + d.day


def make_msno(rng: np.random.Generator) -> str:
    alphabet = list(string.ascii_letters + string.digits + "+/")
    return "".join(rng.choice(alphabet, 43)) + "="


def simulate(n_users: int, seed: int):
    rng = np.random.default_rng(seed)
    members, txns, logs, labels = [], [], [], []

    for _ in range(n_users):
        msno = make_msno(rng)
        reg = SIM_START + timedelta(days=int(rng.integers(0, (date(2017, 2, 15) - SIM_START).days)))
        engagement = rng.beta(2, 2)                      # latent: drives both listening and churn
        city = int(rng.choice([1, 1, 1, 13, 5, 4, 15, 22]))
        bd = int(rng.choice([0, 0, rng.integers(15, 55), rng.integers(15, 55), -43, 1051]))
        gender = rng.choice(["male", "female", ""], p=[0.3, 0.3, 0.4])
        via = int(rng.choice([3, 4, 7, 9, 13]))
        if rng.random() > 0.05:                          # ~5% missing from members, like the real data
            members.append((msno, city, bd, gender, via, d2i(reg)))

        # ---- subscription history --------------------------------------
        plan_i = rng.choice(len(PLANS), p=[p[2] for p in PLANS])
        days, price, _w = PLANS[plan_i]
        auto = days == 30 and rng.random() < 0.75
        method = 41 if auto else int(rng.choice(PAYMENT_METHODS))
        t = reg + timedelta(days=int(rng.integers(0, 60)))
        user_periods = []
        while t <= SIM_END:
            paid = price if rng.random() > 0.04 else 0   # occasional free promo
            exp = t + timedelta(days=days)
            txns.append([msno, method, days, price, paid, int(auto), d2i(t), d2i(exp), 0])
            user_periods.append((t, exp))
            # mid-period cancellation (auto-renew users switching auto-renew off)
            if auto and rng.random() < 0.03:
                c_day = t + timedelta(days=int(rng.integers(1, max(2, days))))
                c_exp = min(exp, c_day + timedelta(days=int(rng.integers(0, 10))))
                txns.append([msno, method, days, price, 0, 0, d2i(c_day), d2i(c_exp), 1])
                user_periods[-1] = (t, c_exp)
                exp = c_exp
                if rng.random() < 0.8:
                    break
            p_churn = (0.035 if auto else 0.22) * (1.6 - engagement) * (1.4 if paid == 0 else 1.0)
            p_churn *= 0.6 if days >= 90 else 1.0
            if rng.random() < p_churn:
                if rng.random() < 0.2:                    # some come back later (reactivation)
                    t = exp + timedelta(days=int(rng.integers(35, 200)))
                    continue
                break
            t = exp - timedelta(days=int(rng.integers(0, 3))) if auto else exp + timedelta(days=int(rng.integers(-5, 25)))

        # ---- churn label (KKBox rule) for memberships expiring in March 2017
        march = [(s, e) for s, e in user_periods if date(2017, 3, 1) <= e <= date(2017, 3, 31)]
        if march:
            s, e = march[-1]
            renewed = any(e - timedelta(days=60) < s2 <= e + timedelta(days=30) and s2 > s for s2, _ in user_periods)
            labels.append((msno, int(not renewed)))

        # ---- daily listening logs while subscribed --------------------------
        for s, e in user_periods:
            lo, hi = max(s, LOG_START), min(e, DATA_END)
            n = (hi - lo).days + 1
            if n <= 0:
                continue
            day_idx = np.arange(n)
            active = rng.random(n) < (0.15 + 0.7 * engagement)
            for k in day_idx[active]:
                d = lo + timedelta(days=int(k))
                songs = rng.poisson(5 + 40 * engagement, 5)
                total = int(songs.sum())
                secs = float(total * rng.normal(210, 25))
                if rng.random() < 0.002:
                    secs = -9.2e15                        # junk value like the real logs
                logs.append([msno, d2i(d), *map(int, songs), max(1, int(total * 0.8)), round(secs, 3)])

    tx = pd.DataFrame(txns, columns=["msno", "payment_method_id", "payment_plan_days", "plan_list_price",
                                     "actual_amount_paid", "is_auto_renew", "transaction_date",
                                     "membership_expire_date", "is_cancel"])
    # dirty data: impossible expiry dates on a few rows, and exact duplicates
    bad = tx.sample(frac=0.003, random_state=seed).index
    tx.loc[bad, "membership_expire_date"] = 19700101
    tx = pd.concat([tx, tx.sample(frac=0.01, random_state=seed + 1)], ignore_index=True)
    lg = pd.DataFrame(logs, columns=["msno", "date", "num_25", "num_50", "num_75", "num_985", "num_100",
                                     "num_unq", "total_secs"])
    mb = pd.DataFrame(members, columns=["msno", "city", "bd", "gender", "registered_via", "registration_init_time"])
    lb = pd.DataFrame(labels, columns=["msno", "is_churn"])
    return mb, tx, lg, lb


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="tests/fixtures/generated")
    ap.add_argument("--users", type=int, default=4000)
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    mb, tx, lg, lb = simulate(a.users, a.seed)
    v1_end, start, end = d2i(V1_END), d2i(DATA_START), d2i(DATA_END)
    tx = tx[(tx.transaction_date >= start) & (tx.transaction_date <= end)]
    lg = lg[(lg.date >= start) & (lg.date <= end)]

    mb.to_csv(out / "members_v3.csv", index=False)
    tx[tx.transaction_date <= v1_end].to_csv(out / "transactions.csv", index=False)
    # transactions_v2 overlaps a little with v1 on purpose (the real files overlap too)
    v2 = pd.concat([tx[tx.transaction_date > v1_end], tx[tx.transaction_date <= v1_end].tail(50)])
    v2.to_csv(out / "transactions_v2.csv", index=False)
    lg[lg.date <= v1_end].to_csv(out / "user_logs.csv", index=False)
    lg[lg.date > v1_end].to_csv(out / "user_logs_v2.csv", index=False)
    lb.to_csv(out / "train_v2.csv", index=False)
    (out / "README_SYNTHETIC.txt").write_text(
        "SYNTHETIC test data generated by scripts/make_fixture.py. Not real. Never report numbers from it.\n")
    print(f"SYNTHETIC fixture -> {out}: members={len(mb)} txns={len(tx)} logs={len(lg)} labels={len(lb)}")


if __name__ == "__main__":
    main()
