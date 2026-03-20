# Study Guide: Cresta Data Scientist, Customer Analytics

Quick-reference notes on the highest-priority concepts for this role.

---

## Statistics & Experimental Design

### Hypothesis Testing
| Concept | Key Point |
|---------|-----------|
| **p-value** | Probability of observing a result this extreme *if the null hypothesis were true*. Not the probability that H0 is true. |
| **Type I error (α)** | False positive — rejecting H0 when it's true. Controlled by your significance threshold (typically 0.05). |
| **Type II error (β)** | False negative — failing to reject H0 when it's false. Related to statistical power (1 - β). |
| **Statistical power** | Probability of detecting a true effect. Depends on: sample size, effect size, variance, α. |
| **Cohen's d** | Effect size: (mean difference) / pooled SD. Small=0.2, Medium=0.5, Large=0.8. |
| **Welch's t-test** | Use instead of Student's t-test when variances may differ between groups (almost always safer). |
| **One-tailed vs. two-tailed** | Two-tailed unless you have a strong prior reason to test directionality only. |

### When t-test is inappropriate
- Non-normal distribution AND small sample (n < 30) → use Mann-Whitney U
- Proportions (e.g., FCR rate) → use proportion z-test or chi-square
- Paired data (same agents before/after) → use paired t-test
- More than 2 groups → ANOVA (then post-hoc tests)

### Confidence Intervals
- 95% CI: if you repeated the experiment 100 times, ~95 of the CIs would contain the true parameter
- **Plain English version**: "We're 95% confident the true effect is between X and Y"
- Non-overlapping CIs ≠ p < 0.05 (this is a common misinterpretation)

---

## Causal Inference

### Key Frameworks

**Difference-in-Differences (DiD)**
- Compares the change in outcomes over time between a treatment group and a control group
- Key assumption: *parallel trends* — both groups would have followed the same trend absent treatment
- Formula: DiD = (Post_T - Pre_T) - (Post_C - Pre_C)
- Good for: phased rollouts, natural experiments

**Propensity Score Matching (PSM)**
- Estimate probability of treatment based on observable covariates
- Match treated units to control units with similar propensity scores
- Goal: make treatment/control groups comparable on observed confounders
- Limitation: doesn't control for *unobserved* confounders

**Regression Discontinuity (RD)**
- Exploit a threshold rule for treatment assignment
- E.g., agents above X score get Cresta first
- Strong internal validity near the threshold

**Instrumental Variables (IV)**
- Use a variable that affects treatment but not the outcome directly
- Hard to find good instruments; rarely used in practice

### Selection Bias in Pilots
Common in contact centers:
- High-performing teams or agents get Cresta first (positive selection)
- Failing accounts get Cresta as a rescue tool (negative selection)
- Always check: are treatment and control groups comparable at baseline?

---

## SQL Quick Reference

### Window Functions
```sql
-- Rank within partition
ROW_NUMBER() OVER (PARTITION BY region ORDER BY call_volume DESC)
RANK()        -- ties get same rank, next rank skips
DENSE_RANK()  -- ties get same rank, next rank does NOT skip

-- Running totals
SUM(metric) OVER (PARTITION BY account_id ORDER BY week_start)

-- Rolling average (last 4 weeks)
AVG(metric) OVER (
    PARTITION BY account_id
    ORDER BY week_start
    ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
)

-- Lag/Lead
LAG(csat, 1) OVER (PARTITION BY account_id ORDER BY month)
```

### Common Patterns
- **Cohort analysis**: DATE_TRUNC on hire_date or first_contact_date, then DATEDIFF for period
- **Retention curve**: count distinct active users in each period relative to cohort size
- **Pre/post**: CASE WHEN date < cutoff THEN 'pre' ELSE 'post' END, then aggregate
- **Self-join gotchas**: Always check for duplicates before joining; use CTEs to isolate

---

## Python / Pandas Quick Reference

### EDA Checklist
```python
df.shape, df.dtypes, df.isnull().sum()
df.describe(include='all')
df["col"].value_counts(normalize=True)
df["numeric"].hist(bins=30)
df.corr()  # pearson by default
```

### Key scipy.stats functions
```python
stats.ttest_ind(a, b, equal_var=False)      # Welch's t-test
stats.mannwhitneyu(a, b, alternative='two-sided')  # non-parametric
stats.chi2_contingency(contingency_table)    # chi-square
stats.pearsonr(x, y)                        # correlation + p-value
stats.norm.ppf(0.975)                       # z-score for 95% CI = 1.96
stats.t.ppf(0.975, df=n-1)                 # t-score for small samples
```

### Useful patterns
```python
# Sample size estimation
from statsmodels.stats.power import TTestIndPower
TTestIndPower().solve_power(effect_size=0.3, alpha=0.05, power=0.8)

# Rolling mean
df.groupby("agent_id")["aht"].transform(lambda x: x.rolling(4).mean())

# % change period-over-period
df["pct_change"] = df.groupby("account_id")["csat"].pct_change()
```

---

## NLP for Conversational Data

### Key Representations
| Method | When to use |
|--------|-------------|
| **TF-IDF** | Keyword importance, topic similarity, simple classification |
| **Word2Vec / GloVe** | Semantic similarity, finding related terms |
| **Sentence embeddings (SBERT)** | Sentence-level similarity, semantic search |
| **Fine-tuned BERT** | High-accuracy classification with labeled data |

### Common Tasks in Contact Centers
- **Intent classification**: What is the customer calling about?
- **Sentiment analysis**: How does the customer feel over the course of the call?
- **Topic modeling** (LDA, BERTopic): Unsupervised discovery of common themes
- **Agent behavior detection**: Is the agent following the script? Using recommended phrasing?
- **Silence/hold time extraction**: From timestamps in structured event logs

### Quick NLP Pipeline
```python
# Minimal text classification pipeline
from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression

pipe = Pipeline([
    ("tfidf", TfidfVectorizer(max_features=5000, ngram_range=(1, 2), stop_words="english")),
    ("clf", LogisticRegression(max_iter=500)),
])
pipe.fit(X_train, y_train)
pipe.predict_proba(X_test)
```

---

## Dashboarding Principles

### Metric Selection
- Every metric should answer a specific business question
- Prefer leading indicators (early signals of outcome) over lagging ones
- Max ~5-7 KPIs per dashboard — more is noise

### Dashboard Design
- Title = the question being answered, not the metric name
- Use sparklines / trend lines to show direction, not just current state
- Red/yellow/green only when thresholds are well-defined and agreed upon
- Always show sample size (n=) alongside averages

### Common Pitfalls
- Averages without distribution info (outliers distort everything in small pilots)
- No baseline / target on the chart
- Multiple competing definitions of the "same" metric across teams

---

## Communication Templates

### Explaining statistical significance to a CSM
> "We're 95% confident that Cresta is responsible for at least X seconds of AHT reduction. The probability that this result happened by random chance is less than 5%."

### Explaining a confidence interval
> "Our best estimate is a 35-second improvement, but accounting for normal variation in the data, the true improvement is likely between 22 and 48 seconds."

### When results aren't significant
> "The data shows a positive trend — AHT is lower with Cresta — but with the current number of agents and timeframe, we can't yet rule out random variation as the cause. Recommendation: extend the pilot by 4 weeks to reach the sample size needed for a definitive conclusion."

---

## Cresta-Specific AI/ML Concepts

You don't need to build these, but you need to speak intelligently about them.

### Ocean-1 (Cresta's Foundation Model)
| Concept | What to know |
|---------|-------------|
| **Architecture** | Mixtral/Mistral-based, fine-tuned for contact center domain |
| **LoRA adapters** | Low-Rank Adaptation — lightweight per-customer customization on top of one shared base model. Enables 1000s of customer-specific adapters from a single model cluster. |
| **Cost advantage** | 100x cheaper than GPT-4 for production inference via domain-specific fine-tuning + LoRA |
| **Serving** | Partnered with Fireworks AI for model serving at scale |

### RAG (Retrieval-Augmented Generation)
- Powers Cresta's Knowledge Assist feature
- Pipeline: real-time conversation → detect knowledge need → search customer's knowledge base → LLM generates grounded response
- **Why it matters for DS**: You may measure RAG quality (answer relevance, latency, usage rates) or analyze which knowledge gaps are most common

### Key AI Concepts for Interview
| Concept | 1-sentence explanation |
|---------|----------------------|
| **Fine-tuning** | Training a pre-trained LLM on domain-specific data to improve performance on specialized tasks |
| **LoRA** | Adds small trainable weight matrices to a frozen model — fast, cheap fine-tuning without retraining the whole model |
| **RAG** | Combines retrieval from a knowledge base with LLM generation to produce grounded, factual answers |
| **Hallucination** | LLM generates plausible but factually incorrect information — mitigated by RAG, guardrails, and evidence-based reasoning |
| **Guardrails** | Rules and models that block harmful, off-topic, or sensitive outputs from AI agents |
| **ASR** | Automatic Speech Recognition — converts voice to text in real-time (critical for Cresta's voice pipeline) |
| **TTS** | Text-to-Speech — converts AI-generated text back to spoken voice (Cresta uses Cartesia's Sonic) |

### How to reference this in interview answers
> "I know Cresta uses Ocean-1 with LoRA adapters per customer rather than generic GPT-4 calls — as a DS, that means the metrics I build for one customer might need to account for model-specific behavior differences across accounts."

> "I'd want to understand how Knowledge Assist usage correlates with AHT reduction — if agents using the RAG-powered suggestions handle calls faster, that's a strong signal for the QBR."

---

## Cresta's Key Numbers (Memorize These)

Reference these in your answers to show you've done your homework.

| Metric | Number | Source |
|--------|--------|--------|
| Total funding | $270M+ | Series D press release |
| Valuation | $1.6B | Series C announcement |
| Series D | $125M (Nov 2024) | Led by WiL + QIA |
| Employees | ~559 | As of Jan 2026 |
| CSAT improvement | +20% | Cresta reported average |
| AHT reduction | -15% | Cresta reported average |
| Onboarding speed | 30% faster | Cresta reported average |
| Revenue per lead | +25% | Cresta reported average |
| FCR improvement | 2.3x with coaching | Cresta reported |
| Ocean-1 cost savings | 100x vs GPT-4 | Cresta engineering blog |
| Languages supported | 30+ | Real-Time Translation launch |

---

## Cresta-Specific Talking Points

### For "Why Cresta?"
1. Vertical AI is more interesting than horizontal — you're not building generic dashboards, you're measuring the causal impact of AI on human performance
2. The measurement challenge is uniquely hard: phased rollouts, selection bias, confounders from contact center operations
3. Direct line from analytics to revenue: your analysis feeds directly into renewal conversations worth millions in ARR

### For "Tell me about your analytical approach"
Always frame around Cresta's value chain:
1. **Measurement** → Does Cresta actually improve performance? (A/B tests, DiD, propensity matching)
2. **Translation** → What does this mean in dollars? (AHT savings × volume × agent cost)
3. **Communication** → Can the CSM walk into a QBR with confidence? (Executive summary, methodology backup, objection handling)

### For product-aware answers
- Reference **Agent Assist** when discussing coaching effectiveness measurement
- Reference **Conversation Intelligence** when discussing QBR/dashboard work
- Reference **Automation Discovery** when discussing which conversations to automate (readiness scoring)
- Reference **AI Analyst** when discussing scalable insights (natural language queries over conversation data)
- Reference **Knowledge Agent** when discussing real-time agent support measurement
