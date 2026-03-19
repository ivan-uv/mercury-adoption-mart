"""
Cresta Python Practice — Solutions
Data Scientist, Customer Analytics

Topics:
1. Pandas / EDA
2. Hypothesis testing & A/B analysis
3. Quasi-experiments (DiD)
4. Segmentation / clustering
5. Basic NLP for conversational data
"""

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from collections import Counter
import re


# ============================================================
# 1. PANDAS / EDA
# ============================================================

def compute_aht_summary(conversations: pd.DataFrame) -> pd.DataFrame:
    """
    Given a DataFrame with columns:
        agent_id, conversation_id, started_at, ended_at, account_id
    Return weekly AHT summary per agent.
    """
    df = conversations.copy()
    df["started_at"] = pd.to_datetime(df["started_at"])
    df["ended_at"] = pd.to_datetime(df["ended_at"])
    df["handle_time_sec"] = (df["ended_at"] - df["started_at"]).dt.total_seconds()
    df["week"] = df["started_at"].dt.to_period("W").dt.start_time

    return (
        df.groupby(["agent_id", "week"])
        .agg(
            call_volume=("conversation_id", "count"),
            avg_aht=("handle_time_sec", "mean"),
            median_aht=("handle_time_sec", "median"),
            p90_aht=("handle_time_sec", lambda x: x.quantile(0.9)),
        )
        .reset_index()
    )


def flag_outlier_agents(df: pd.DataFrame, aht_col: str = "avg_aht", z_thresh: float = 2.5) -> pd.DataFrame:
    """
    Flag agents whose AHT is more than z_thresh standard deviations from the mean.
    Returns a copy with z_score and is_outlier columns.
    """
    df = df.copy()
    mean = df[aht_col].mean()
    std = df[aht_col].std()
    df["z_score"] = (df[aht_col] - mean) / std
    df["is_outlier"] = df["z_score"].abs() > z_thresh
    return df


# ============================================================
# 2. HYPOTHESIS TESTING & A/B ANALYSIS
# ============================================================

def two_sample_ttest(
    control: np.ndarray,
    treatment: np.ndarray,
    alpha: float = 0.05,
) -> dict:
    """
    Welch's two-sample t-test with effect size and confidence interval.
    """
    t_stat, p_value = stats.ttest_ind(treatment, control, equal_var=False)

    pooled_std = np.sqrt((treatment.std() ** 2 + control.std() ** 2) / 2)
    cohens_d = (treatment.mean() - control.mean()) / pooled_std

    diff = treatment.mean() - control.mean()
    se = np.sqrt(treatment.var() / len(treatment) + control.var() / len(control))
    ci_low = diff - 1.96 * se
    ci_high = diff + 1.96 * se

    return {
        "control_mean": round(control.mean(), 4),
        "treatment_mean": round(treatment.mean(), 4),
        "difference": round(diff, 4),
        "pct_change": round(diff / control.mean() * 100, 2),
        "t_statistic": round(t_stat, 4),
        "p_value": round(p_value, 4),
        "significant": p_value < alpha,
        "cohens_d": round(cohens_d, 4),
        "ci_95": (round(ci_low, 4), round(ci_high, 4)),
    }


def compute_required_sample_size(
    baseline_mean: float,
    baseline_std: float,
    mde: float,
    alpha: float = 0.05,
    power: float = 0.80,
) -> int:
    """
    Minimum sample size per group for a two-sample t-test.
    """
    z_alpha = stats.norm.ppf(1 - alpha / 2)
    z_beta = stats.norm.ppf(power)
    effect_size = mde / baseline_std
    n = 2 * ((z_alpha + z_beta) / effect_size) ** 2
    return int(np.ceil(n))


def summarize_pilot_results(
    pre_control: np.ndarray,
    post_control: np.ndarray,
    pre_treatment: np.ndarray,
    post_treatment: np.ndarray,
) -> dict:
    """
    Difference-in-Differences estimator with bootstrap confidence interval.
    """
    treatment_delta = post_treatment.mean() - pre_treatment.mean()
    control_delta = post_control.mean() - pre_control.mean()
    did_estimate = treatment_delta - control_delta

    np.random.seed(42)
    bootstrap_dids = []
    for _ in range(2000):
        bt_pre_c  = np.random.choice(pre_control,   len(pre_control),   replace=True)
        bt_post_c = np.random.choice(post_control,  len(post_control),  replace=True)
        bt_pre_t  = np.random.choice(pre_treatment, len(pre_treatment), replace=True)
        bt_post_t = np.random.choice(post_treatment,len(post_treatment),replace=True)
        bootstrap_dids.append(
            (bt_post_t.mean() - bt_pre_t.mean()) - (bt_post_c.mean() - bt_pre_c.mean())
        )

    bootstrap_dids = np.array(bootstrap_dids)
    ci_low, ci_high = np.percentile(bootstrap_dids, [2.5, 97.5])
    p_value = np.mean(np.abs(bootstrap_dids) >= np.abs(did_estimate))

    return {
        "treatment_delta": round(treatment_delta, 4),
        "control_delta": round(control_delta, 4),
        "did_estimate": round(did_estimate, 4),
        "p_value_approx": round(p_value, 4),
        "ci_95": (round(ci_low, 4), round(ci_high, 4)),
        "significant": p_value < 0.05,
    }


# ============================================================
# 3. ACCOUNT SEGMENTATION
# ============================================================

def segment_accounts(account_features: pd.DataFrame, n_clusters: int = 4) -> pd.DataFrame:
    """
    K-means segmentation of accounts on numeric features.
    """
    df = account_features.copy()
    numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()

    X_scaled = StandardScaler().fit_transform(df[numeric_cols])
    kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
    df["segment"] = kmeans.fit_predict(X_scaled)

    if "avg_csat" in numeric_cols:
        segment_csat = df.groupby("segment")["avg_csat"].mean().sort_values(ascending=False)
        label_map = {seg: f"Tier {i+1}" for i, seg in enumerate(segment_csat.index)}
        df["segment_label"] = df["segment"].map(label_map)

    return df


# ============================================================
# 4. BASIC NLP FOR CONVERSATIONAL DATA
# ============================================================

def clean_transcript(text: str) -> str:
    """Lowercase, remove speaker labels, strip non-alpha chars."""
    text = text.lower()
    text = re.sub(r"\b(agent|customer|rep|caller)\s*:", "", text)
    text = re.sub(r"[^a-z\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_top_ngrams(
    transcripts: list[str],
    n: int = 2,
    top_k: int = 20,
    stopwords: set = None,
) -> list[tuple[str, int]]:
    """Top n-grams across a corpus of transcripts."""
    if stopwords is None:
        stopwords = {
            "i", "you", "we", "the", "a", "an", "is", "it", "to", "and",
            "that", "this", "of", "in", "for", "my", "your", "on", "at",
            "with", "can", "was", "are", "have", "do", "be", "so", "just",
        }

    all_ngrams = []
    for transcript in transcripts:
        tokens = [
            t for t in clean_transcript(transcript).split()
            if t not in stopwords and len(t) > 2
        ]
        all_ngrams.extend(" ".join(gram) for gram in zip(*[tokens[i:] for i in range(n)]))

    return Counter(all_ngrams).most_common(top_k)


def rule_based_intent_classifier(transcript: str) -> str:
    """Keyword-based intent classification. First match wins."""
    text = transcript.lower()
    rules = {
        "escalation":   ["supervisor", "manager", "escalate", "unacceptable", "complaint"],
        "cancellation": ["cancel", "cancellation", "close account", "stop service", "end my plan"],
        "billing":      ["charge", "invoice", "bill", "payment", "refund", "overcharged"],
        "technical":    ["not working", "error", "broken", "outage", "can't connect", "issue with"],
    }
    for intent, keywords in rules.items():
        if any(kw in text for kw in keywords):
            return intent
    return "general"


def compute_sentiment_score(transcript: str) -> float:
    """Naive lexicon-based sentiment in [-1, 1]."""
    positive_words = {
        "great", "excellent", "helpful", "thank", "resolved",
        "happy", "appreciate", "wonderful", "perfect", "love",
    }
    negative_words = {
        "terrible", "awful", "frustrated", "angry", "unacceptable",
        "worst", "disappointed", "hate", "useless", "ridiculous",
    }

    tokens = set(clean_transcript(transcript).split())
    pos_count = len(tokens & positive_words)
    neg_count = len(tokens & negative_words)
    total = pos_count + neg_count
    if total == 0:
        return 0.0
    return round((pos_count - neg_count) / total, 4)


# ============================================================
# DEMO
# ============================================================

if __name__ == "__main__":
    np.random.seed(42)

    # --- A/B test ---
    control_aht   = np.random.normal(loc=420, scale=60, size=150)
    treatment_aht = np.random.normal(loc=390, scale=58, size=150)
    result = two_sample_ttest(control_aht, treatment_aht)
    print("=== A/B Test: Handle Time ===")
    for k, v in result.items():
        print(f"  {k}: {v}")

    # --- Sample size ---
    n = compute_required_sample_size(baseline_mean=420, baseline_std=60, mde=25)
    print(f"\n=== Required sample size per group: {n} agents ===")

    # --- DiD ---
    did = summarize_pilot_results(
        pre_control=np.random.normal(415, 55, 80),
        post_control=np.random.normal(418, 55, 80),
        pre_treatment=np.random.normal(420, 60, 80),
        post_treatment=np.random.normal(385, 58, 80),
    )
    print("\n=== Difference-in-Differences ===")
    for k, v in did.items():
        print(f"  {k}: {v}")

    # --- NLP ---
    samples = [
        "Agent: Hi there, how can I help? Customer: I've been charged twice this month and I'm very frustrated.",
        "Agent: I understand. Customer: My account is not working and I want to cancel.",
        "Agent: Let me transfer you to my supervisor. Customer: Finally, someone better help me.",
    ]
    print("\n=== Intent & Sentiment ===")
    for s in samples:
        print(f"  {rule_based_intent_classifier(s):15s} | {compute_sentiment_score(s):+.3f} | {s[:60]}...")

    print("\n=== Top Bigrams ===")
    for gram, count in extract_top_ngrams(samples, n=2, top_k=10):
        print(f"  {gram}: {count}")
