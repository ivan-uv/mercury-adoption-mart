"""
Page 1: Weekly Meal Planner
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

import streamlit as st
import pandas as pd

st.set_page_config(page_title="Meal Planner | Family Fuel", page_icon="🗓", layout="wide")

from dashboard.app import get_db

con = get_db()

st.title("🗓 Weekly Meal Planner")
st.caption("Your week of meals, built from your recipe library.")

# ── Filters ───────────────────────────────────────────────────
with st.sidebar:
    st.subheader("Filters")
    target_cal = st.selectbox(
        "Target calories / day",
        options=[1500, 1800, 2000, 2200, 2500],
        index=2,
    )
    max_prep = st.slider("Max prep time (min)", 15, 60, 45, step=5)
    diet_filters = st.multiselect(
        "Dietary requirements",
        options=["vegetarian", "vegan", "gluten-free", "dairy-free"],
    )
    kid_only = st.checkbox("Kid-friendly only", value=False)

# ── Query mart_weekly_plans ───────────────────────────────────
try:
    df: pd.DataFrame = con.execute("""
        SELECT
            day_of_week,
            meal_slot,
            title,
            cuisine,
            ready_minutes,
            calories_per_serving,
            image_url,
            source_url,
            diet_tags,
            kid_friendly
        FROM mart_weekly_plans
        ORDER BY day_of_week, meal_slot
    """).df()
except Exception as e:
    st.error(f"Could not load meal plan: {e}")
    st.info("Run `python etl/run_pipeline.py` to generate a meal plan.")
    st.stop()

if df.empty:
    st.warning("No meal plan found. Run the ETL pipeline to generate one.")
    st.stop()

# Apply filters
if max_prep < 60:
    df = df[df["ready_minutes"] <= max_prep]
if kid_only:
    df = df[df["kid_friendly"]]
if diet_filters:
    for tag in diet_filters:
        df = df[df["diet_tags"].apply(lambda tags: tag in (tags or []))]

# ── Render 3×7 grid ──────────────────────────────────────────
DAY_NAMES = {1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun"}
MEAL_ORDER = ["breakfast", "lunch", "dinner"]
MEAL_EMOJI = {"breakfast": "🌅", "lunch": "☀️", "dinner": "🌙"}

cols = st.columns(7)
for day_num, col in zip(range(1, 8), cols):
    col.markdown(f"**{DAY_NAMES[day_num]}**")
    for slot in MEAL_ORDER:
        row = df[(df["day_of_week"] == day_num) & (df["meal_slot"] == slot)]
        if row.empty:
            col.caption(f"{MEAL_EMOJI[slot]} *No meal*")
        else:
            r = row.iloc[0]
            cal = int(r["calories_per_serving"]) if pd.notna(r["calories_per_serving"]) else "?"
            prep = int(r["ready_minutes"]) if pd.notna(r["ready_minutes"]) else "?"
            label = r["title"]
            link = r["source_url"] if pd.notna(r["source_url"]) else "#"
            col.markdown(
                f"{MEAL_EMOJI[slot]} [{label}]({link})\n\n"
                f"*{cal} kcal · {prep} min*"
            )

# ── Daily calorie summary vs target ────────────────────────
st.divider()
if not df.empty:
    daily_cals = df.groupby("day_of_week")["calories_per_serving"].sum().reset_index()
    daily_cals.columns = ["day_of_week", "total_calories"]
    daily_cals["day_name"] = daily_cals["day_of_week"].map(DAY_NAMES)
    over_days = (daily_cals["total_calories"] > target_cal).sum()
    under_days = (daily_cals["total_calories"] < target_cal * 0.8).sum()
    if over_days > 0:
        st.warning(f"{over_days} day(s) exceed {target_cal} kcal target")
    if under_days > 0:
        st.info(f"{under_days} day(s) are more than 20% below {target_cal} kcal target")

st.caption(f"Showing {len(df)} meal slots · target {target_cal} kcal/day")
