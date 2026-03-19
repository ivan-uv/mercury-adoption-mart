# Case Study: Proving Cresta's Impact for a Renewal

**Scenario**: Intuit has been live with Cresta for 6 months across their SMB customer support team (220 agents). Their contract renewal ($1.2M ARR) is in 60 days. The VP of Customer Experience wants proof that Cresta improved agent performance. Your CSM asks you for a data-backed story.

---

## Step 1: Clarify the Business Question

Before touching data, ask:
- What does "improved agent performance" mean to *them*? AHT? CSAT? FCR? Agent attrition?
- Do they have a control group, or did everyone go live at once?
- What's the pre-Cresta data availability? How far back?
- Were there any confounders during the period? (Seasonality, product launches, staffing changes?)

**Primary metrics** (tied to their exec's priorities):
- Average Handle Time (AHT) — cost efficiency
- Customer Satisfaction Score (CSAT) — customer experience
- First Call Resolution (FCR) — quality

**Secondary metrics** (supporting story):
- Agent coaching touchpoints per conversation
- Transfer rate
- Agent ramp time (new hire productivity curves)

---

## Step 2: Design the Measurement Approach

### Option A: Pre/Post with Trend Adjustment (most common)
Compare 8 weeks pre-launch vs. 6 months post-launch. Control for trend by fitting a linear model to the pre-period and extrapolating what would have happened without Cresta.

**Pros**: Simple, works when there's no control group.
**Cons**: Assumes counterfactual trend is stable. Seasonality is a real risk.

### Option B: Agent-Level Treatment vs. Control (if partial rollout)
If some agents were enabled before others, compare Cresta-enabled agents to not-yet-enabled agents in the same time window.

**Pros**: Removes temporal confounders (seasonality, macro changes).
**Cons**: Selection bias — were the "best" agents onboarded first?
**Fix**: Propensity score matching on pre-period agent characteristics (tenure, baseline AHT, call volume).

### Option C: Synthetic Control (if you have comparable accounts)
Identify similar contact centers (different Cresta customers or internal teams) that *didn't* use Cresta and use them as the counterfactual.

**For this scenario**: Use Option B (Intuit did a phased rollout by team), adjusted for selection bias via matching.

---

## Step 3: Execute the Analysis

### 3a. Build the baseline dataset

```python
import pandas as pd
import numpy as np
from scipy import stats

# Load agent-level weekly data
df = pd.read_csv("intuit_agent_weekly.csv", parse_dates=["week_start"])

# Define treatment based on cresta_enabled_date
df["is_treatment"] = df["cresta_enabled_date"].notna()
df["weeks_since_enabled"] = (
    df["week_start"] - df["cresta_enabled_date"]
).dt.days / 7
```

### 3b. Propensity score matching

Match treatment agents to control agents on:
- Pre-period average AHT
- Pre-period average CSAT
- Tenure (months)
- Call volume (weekly average)

```python
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler

# Compute pre-period baseline features per agent
pre_period = df[df["week_start"] < GOLIVE_DATE]
agent_baseline = pre_period.groupby("agent_id").agg(
    pre_aht=("avg_aht_sec", "mean"),
    pre_csat=("csat_avg", "mean"),
    tenure_months=("tenure_months", "first"),
    weekly_volume=("call_volume", "mean"),
    is_treatment=("is_treatment", "first"),
).reset_index()

# Fit propensity model
features = ["pre_aht", "pre_csat", "tenure_months", "weekly_volume"]
X = StandardScaler().fit_transform(agent_baseline[features])
y = agent_baseline["is_treatment"].astype(int)

lr = LogisticRegression()
lr.fit(X, y)
agent_baseline["propensity"] = lr.predict_proba(X)[:, 1]

# Nearest-neighbor matching (simplified)
# In practice: use sklearn NearestNeighbors or causalml library
```

### 3c. Run the comparison

```python
# Post-period: 6 months after Cresta go-live
post = df[df["week_start"] >= GOLIVE_DATE]

treatment_aht = post[post["is_treatment"]]["avg_aht_sec"].values
control_aht = post[~post["is_treatment"]]["avg_aht_sec"].values

t_stat, p_val = stats.ttest_ind(treatment_aht, control_aht, equal_var=False)
pct_diff = (treatment_aht.mean() - control_aht.mean()) / control_aht.mean() * 100

print(f"Treatment AHT: {treatment_aht.mean():.0f}s")
print(f"Control AHT:   {control_aht.mean():.0f}s")
print(f"Difference:    {pct_diff:.1f}%  (p={p_val:.4f})")
```

---

## Step 4: Translate to Business Value

Don't stop at statistical significance. CSMs and executives need dollar impact.

**AHT savings formula**:
```
AHT reduction (sec) × calls per agent per year × num agents × blended agent cost per second
= Annual cost savings
```

Example:
- AHT reduced from 420s → 385s = **35 seconds saved per call**
- 220 agents × 800 calls/yr = 176,000 calls/yr
- Agent cost: ~$0.25/sec (fully loaded)
- **176,000 × 35 × $0.25 = $1,540,000 in annual savings**

This is 1.28× the contract value — a compelling ROI story.

---

## Step 5: Build the QBR Deliverable

Structure:
1. **Executive Summary** (1 slide): Before/after KPI table, dollar impact, confidence level
2. **Methodology** (1 slide, optional): For technically curious stakeholders
3. **Deep Dive by Team** (2-3 slides): Which teams improved most, laggards to focus on
4. **Agent Trajectory** (1 slide): Ramp time for new agents with Cresta vs. without
5. **Next Quarter Opportunities** (1 slide): Where Cresta can drive additional value

---

## Potential Objections & Responses

**"AHT dropped but CSAT didn't improve — was it just rushing customers?"**
Check whether FCR held steady. If resolution rate is flat or improved, speed gains are real efficiency, not corners being cut.

**"The control group had lower-performing agents to begin with."**
This is why propensity matching matters. Show the baseline equivalence plot — pre-period AHT and CSAT were statistically similar between matched groups.

**"Seasonality could explain the CSAT improvement."**
Check the control group's trend. If both groups had similar seasonal patterns but treatment outperformed, seasonality is controlled for.

**"This is just agent experience maturing over time, not Cresta."**
Compare agent tenure cohorts. New agents with Cresta should ramp faster than historical new agents without it.

---

## What a Strong Answer Looks Like in an Interview

> "I'd start by clarifying what success means to the customer's exec team — not just which metrics, but what business outcome those metrics are tied to. Then I'd design around the rollout structure: if it was phased, I can do a treatment/control comparison and clean up selection bias with matching. If it was all-at-once, I'd use a pre/post with trend adjustment and be upfront about the limitations. I'd translate the statistical result into a dollar figure using their call volume and cost structure, and I'd package it as something the CSM can walk into the QBR with confidence — one executive summary slide, supporting detail behind it, and a clear narrative about *why* Cresta drove the result, not just *that* it did."
