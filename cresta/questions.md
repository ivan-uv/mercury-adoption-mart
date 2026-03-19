# Cresta Interview Question Bank

---

## 1. Role Fit & Motivation

- Why Cresta? Why this role specifically?
- Tell me about a time you turned an ambiguous business question into a structured analysis.
- What does "customer value realization" mean to you, and how would you measure it?
- How do you think about the relationship between analytics and customer success teams?
- What's the difference between a metric that's *interesting* and one that's *actionable*?

**Strong answer frame**: Lead with the business outcome, then the methodology. Never start with "I ran a regression."

---

## 2. SQL

### Conceptual
- What's the difference between `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()`? When do you use each?
- When would you use a CTE vs. a subquery vs. a temp table?
- Explain window functions. Give a business example where they're useful.
- What's the difference between `INNER JOIN`, `LEFT JOIN`, and `FULL OUTER JOIN`? When does `LEFT JOIN` surprise you?
- How do you handle slowly changing dimensions in SQL?

### Scenario-based
- *"We have a table of agent conversation events (one row per event, with timestamp, agent_id, conversation_id, and event_type). Write a query to find the average handle time per agent per week."*
- *"Given a table of pilot accounts and their KPIs before and after Cresta deployment, write a query to compute the % change in average handle time per account."*
- *"We want to flag accounts where CSAT score dropped more than 10 points month-over-month. How would you write that?"*
- *"Find the top 3 agents by call volume in each region for the last 30 days."*
- *"Given a sessions table and an outcomes table, identify conversion rate by agent cohort (based on their hire month)."*

See `sql_practice.sql` for worked examples.

---

## 3. Python & Statistics

### Statistics / Experimental Design
- What is statistical power? What factors affect it?
- A pilot has 50 agents in treatment and 50 in control. After 4 weeks, treatment AHT dropped 8% vs control's 2%. Is this significant? What else do you need to know?
- Explain p-values in plain English to a CSM who has no stats background.
- What's a Type I vs Type II error? Which is worse in a pilot measurement context, and why?
- When is a t-test inappropriate? What would you use instead?
- What is a confidence interval and how do you explain it to a non-technical stakeholder?
- What's the difference between correlation and causation? Give a contact center example.
- What is selection bias and how can it affect pilot results?

### Causal Inference
- What is a quasi-experiment? When would you use one vs. a true A/B test?
- Explain difference-in-differences (DiD). What assumptions does it require?
- What is propensity score matching and when would you use it?
- What's the fundamental problem of causal inference?
- A customer wants to know if Cresta caused their CSAT improvement. You can't randomize. How do you approach this?

### Python / Coding
- Walk me through how you'd clean a messy dataset of call transcripts in Pandas.
- How would you detect outliers in a distribution of handle times? What's your preferred method?
- Write a function to compute a two-sample t-test from scratch (without scipy). What does it return?
- How would you build a simple classifier to tag customer intents from call transcripts?
- Given a time series of weekly CSAT scores for 100 accounts, how would you identify accounts trending negatively?
- How would you segment accounts into tiers using unsupervised learning? What features would you use?

See `python_practice.py` for worked examples.

---

## 4. Dashboards & Reporting

- What makes a good dashboard vs. a bad one?
- How do you decide what metrics to put on a QBR dashboard?
- Walk me through how you'd build a standardized pilot measurement package from scratch.
- A CSM says "the dashboard is too complicated." How do you respond?
- What's your process for defining metrics before building a dashboard?
- How do you ensure dashboard data is trustworthy? What tests do you apply?
- Describe a reporting artifact you built that got repeated use. What made it stick?

---

## 5. Conversational / NLP

- Have you worked with call transcripts or chat logs? What were the challenges?
- How would you extract intent categories from a corpus of customer service conversations?
- What's TF-IDF? When is it useful for conversational data?
- How would you measure "agent coaching effectiveness" using conversation data?
- What's the difference between a keyword-based approach and an embedding-based approach for text classification? Tradeoffs?
- If you had to build a simple sentiment classifier with no labeled data, how would you start?

---

## 6. Business Case / Scenario

- *"A strategic customer is up for renewal in 60 days. Their executive wants to see proof that Cresta improved agent performance. You have 6 months of data. Walk me through your analysis plan."*
- *"We want to run a pilot with a new customer — 100 agents for 8 weeks. Design the measurement framework from scratch."*
- *"Two accounts have identical Cresta usage stats but very different CSAT trends. How do you investigate?"*
- *"The Sales team wants a one-pager showing ROI for a prospect. What would you put on it and how would you make it defensible?"*

See `case_study.md` for a full worked example.

---

## 7. Cross-Functional & Behavioral

- Tell me about a time you had to explain a complex statistical finding to a non-technical audience.
- Describe a situation where your analysis changed a business decision.
- Tell me about a time your analysis was wrong or incomplete. What happened?
- How do you handle competing priorities from multiple stakeholders (CSM, BV, Sales)?
- Give an example of a time you proactively identified an analytical need before someone asked.
- How do you build trust with a team that's skeptical of data?
- Tell me about a time you automated something that used to be manual. What was the impact?

**STAR format**: Situation → Task → Action → Result (quantify the result whenever possible)

---

## 8. Questions to Ask Cresta

- What does the data infrastructure look like today — how does customer data flow from the product into your analytics environment?
- What does a "good QBR" look like at Cresta today, and where does analytics fall short?
- How do you currently handle customers who push back on pilot results?
- What's the biggest analytical challenge the Customer Success team faces that this role is meant to solve?
- How does this role interact with the data/engineering team — is there a shared data platform, or is this role building its own pipelines?
- What would make someone who's hired into this role a clear success at 6 months?
