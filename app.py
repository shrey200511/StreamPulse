from pathlib import Path
import pandas as pd
import streamlit as st
import plotly.express as px

st.set_page_config(page_title="StreamPulse Analytics", page_icon="📊", layout="wide")
DATA = Path(__file__).parent / "data" / "tableau"
FILES = {
    "Monthly KPIs": "monthly_kpis.csv",
    "Cohort retention": "cohort_retention.csv",
    "Churn by segment": "churn_by_segment.csv",
    "Churn drivers": "churn_drivers.csv",
    "LTV by segment": "ltv_by_segment.csv",
    "Value at risk": "value_at_risk.csv",
    "Data quality": "data_quality.csv",
    "Subscriber forecast": "subscriber_forecast.csv",
}

@st.cache_data
def load(name):
    p = DATA / FILES[name]
    return pd.read_csv(p) if p.exists() else pd.DataFrame()

st.title("📊 StreamPulse")
st.caption("Subscriber analytics · Retention · Churn · Revenue · Forecasts")
st.warning("SYNTHETIC DEMO DATA — these smoke-test results are illustrative only, not validated business findings.")

frames = {name: load(name) for name in FILES}
missing = [FILES[n] for n, df in frames.items() if df.empty]
if missing:
    st.error("Missing/empty CSV files in data/tableau: " + ", ".join(missing))

kpi = frames["Monthly KPIs"].copy()
if not kpi.empty and "month_start" in kpi:
    kpi["month_start"] = pd.to_datetime(kpi["month_start"], errors="coerce")
    kpi = kpi.sort_values("month_start")

with st.sidebar:
    st.header("Filters")
    if not kpi.empty and kpi["month_start"].notna().any():
        lo, hi = kpi["month_start"].min().date(), kpi["month_start"].max().date()
        dr = st.date_input("KPI date range", (lo, hi), min_value=lo, max_value=hi)
        if isinstance(dr, tuple) and len(dr) == 2:
            kpi = kpi[kpi["month_start"].dt.date.between(dr[0], dr[1])]

def lastval(df, col):
    if df.empty or col not in df: return None
    s = pd.to_numeric(df[col], errors="coerce").dropna()
    return None if s.empty else s.iloc[-1]

def number(v):
    return "N/A" if v is None or pd.isna(v) else f"{v:,.0f}"

def money(v):
    return "N/A" if v is None or pd.isna(v) else f"NT$ {v:,.0f}"

churn = lastval(kpi, "renewal_churn_rate")
if churn is not None and churn <= 1: churn *= 100
a,b,c,d = st.columns(4)
a.metric("Active subscribers", number(lastval(kpi, "active_subscribers")))
b.metric("Monthly revenue", money(lastval(kpi, "revenue_ntd")))
c.metric("ARPU", money(lastval(kpi, "arpu_ntd")))
d.metric("Renewal churn", "N/A" if churn is None else f"{churn:.1f}%")

overview, retention, churntab, value, forecast, quality, explore = st.tabs(
    ["Overview", "Retention", "Churn", "Customer value", "Forecast", "Data quality", "Explore data"]
)

with overview:
    st.subheader("Monthly performance")
    if kpi.empty: st.info("No KPI rows available.")
    else:
        x, y = st.columns(2)
        if "revenue_ntd" in kpi:
            with x:
                st.plotly_chart(px.line(kpi, x="month_start", y="revenue_ntd", markers=True, title="Monthly revenue (NTD)"), use_container_width=True)
        if "active_subscribers" in kpi:
            with y:
                st.plotly_chart(px.line(kpi, x="month_start", y="active_subscribers", markers=True, title="Active subscribers"), use_container_width=True)
        cols = [c for c in ["month_start","active_subscribers","new_customers","revenue_ntd","arpu_ntd","renewal_churn_rate"] if c in kpi]
        st.dataframe(kpi[cols], use_container_width=True, hide_index=True)

with retention:
    df = frames["Cohort retention"].copy()
    st.subheader("Cohort retention")
    if df.empty: st.info("No cohort data available.")
    else:
        if "first_plan_group" in df:
            plans = ["All"] + sorted(df["first_plan_group"].dropna().astype(str).unique())
            p = st.selectbox("Plan group", plans)
            if p != "All": df = df[df["first_plan_group"].astype(str) == p]
        if {"cohort_month","months_since_signup","retention_rate"}.issubset(df.columns):
            df["retention_pct"] = pd.to_numeric(df["retention_rate"], errors="coerce")
            if df["retention_pct"].dropna().max() <= 1: df["retention_pct"] *= 100
            heat = df.pivot_table(index="cohort_month", columns="months_since_signup", values="retention_pct", aggfunc="mean")
            st.plotly_chart(px.imshow(heat, aspect="auto", color_continuous_scale="Blues", labels={"x":"Months since signup","y":"Cohort","color":"Retention %"}, title="Retention heatmap"), use_container_width=True)
        st.dataframe(df, use_container_width=True, hide_index=True)

with churntab:
    st.subheader("Churn by segment")
    df = frames["Churn by segment"].copy()
    if df.empty: st.info("No segment churn data available.")
    else:
        if "dimension" in df:
            dims = ["All"] + sorted(df["dimension"].dropna().astype(str).unique())
            selected = st.selectbox("Dimension", dims)
            if selected != "All": df = df[df["dimension"].astype(str) == selected]
        if {"segment","churn_rate"}.issubset(df.columns):
            df["churn_pct"] = pd.to_numeric(df["churn_rate"], errors="coerce")
            if df["churn_pct"].dropna().max() <= 1: df["churn_pct"] *= 100
            df = df.sort_values("churn_pct", ascending=False)
            st.plotly_chart(px.bar(df.head(25), x="segment", y="churn_pct", title="Highest churn segments", labels={"churn_pct":"Churn rate (%)"}), use_container_width=True)
        st.dataframe(df, use_container_width=True, hide_index=True)
    st.subheader("Churn drivers")
    st.dataframe(frames["Churn drivers"], use_container_width=True, hide_index=True)

with value:
    st.subheader("Lifetime value by segment")
    df = frames["LTV by segment"].copy()
    if df.empty: st.info("No LTV data available.")
    else:
        if {"segment","avg_value_12m_ntd"}.issubset(df.columns):
            df["avg_value_12m_ntd"] = pd.to_numeric(df["avg_value_12m_ntd"], errors="coerce")
            st.plotly_chart(px.bar(df.sort_values("avg_value_12m_ntd", ascending=False).head(20), x="segment", y="avg_value_12m_ntd", title="Average 12-month value (NTD)"), use_container_width=True)
        st.dataframe(df, use_container_width=True, hide_index=True)
    st.subheader("Revenue at risk")
    df = frames["Value at risk"].copy()
    if df.empty: st.info("No revenue-at-risk data available.")
    else:
        if {"segment_label","monthly_revenue_lost_ntd"}.issubset(df.columns):
            df["monthly_revenue_lost_ntd"] = pd.to_numeric(df["monthly_revenue_lost_ntd"], errors="coerce")
            st.plotly_chart(px.bar(df.sort_values("monthly_revenue_lost_ntd", ascending=False).head(15), x="segment_label", y="monthly_revenue_lost_ntd", title="Estimated monthly revenue lost (NTD)"), use_container_width=True)
        st.dataframe(df, use_container_width=True, hide_index=True)

with forecast:
    st.subheader("Subscriber forecast")
    df = frames["Subscriber forecast"].copy()
    if df.empty: st.info("No forecast data available.")
    else:
        df["month_start"] = pd.to_datetime(df["month_start"], errors="coerce")
        for col in ["forecast","low_95","high_95"]:
            if col in df: df[col] = pd.to_numeric(df[col], errors="coerce")
        if {"month_start","forecast"}.issubset(df.columns):
            fig = px.line(df, x="month_start", y="forecast", markers=True, title="Forecast subscribers")
            for col in ["low_95","high_95"]:
                if col in df: fig.add_scatter(x=df["month_start"], y=df[col], mode="lines", name=col.replace("_"," "), line=dict(dash="dash"))
            st.plotly_chart(fig, use_container_width=True)
        st.dataframe(df, use_container_width=True, hide_index=True)

with quality:
    st.subheader("Data quality checks")
    st.dataframe(frames["Data quality"], use_container_width=True, hide_index=True)

with explore:
    options = [name for name, df in frames.items() if not df.empty]
    if options:
        name = st.selectbox("Dataset", options, key="explore_dataset")
        df = frames[name]
        st.caption(f"{len(df):,} rows · {len(df.columns)} columns")
        st.dataframe(df, use_container_width=True, hide_index=True)
        st.download_button("Download CSV", df.to_csv(index=False).encode("utf-8"), FILES[name], "text/csv")
    else: st.info("No datasets loaded.")

st.divider()
st.caption("StreamPulse · Synthetic test data only. Validate data and methods before business use.")
