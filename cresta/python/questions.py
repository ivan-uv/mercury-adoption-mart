"""
Cresta Python Practice — Questions
Data Scientist, Customer Analytics

Implement each function below. Do not modify signatures or docstrings.
Run solutions.py to compare your output.

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
        agent_id, conversation_id, started_at (str/datetime), ended_at (str/datetime), account_id

    Return a weekly summary per agent with columns:
        agent_id | week (week-start date) | call_volume | avg_aht | median_aht | p90_aht

    Notes:
    - handle_time_sec = (ended_at - started_at).total_seconds()
    - Use to_period('W') to floor to week
    """
    raise NotImplementedError


def flag_outlier_agents(df: pd.DataFrame, aht_col: str = "avg_aht", z_thresh: float = 2.5) -> pd.DataFrame:
    """
    Given a DataFrame of agent-level AHT data, flag agents whose AHT is more
    than z_thresh standard deviations from the mean.

    Return a copy with two new columns:
    - z_score: the agent's z-score for the given aht_col
    - is_outlier: True if abs(z_score) > z_thresh
    """
    raise NotImplementedError


# ============================================================
# 2. HYPOTHESIS TESTING & A/B ANALYSIS
# ============================================================

def two_sample_ttest(
    control: np.ndarray,
    treatment: np.ndarray,
    alpha: float = 0.05,
) -> dict:
    """
    Run a Welch's two-sample t-test comparing treatment vs. control.

    Return a dict with keys:
        control_mean, treatment_mean, difference, pct_change,
        t_statistic, p_value, significant (bool),
        cohens_d, ci_95 (tuple of floats)

    Notes:
    - Use equal_var=False (Welch's, not Student's)
    - Cohen's d = (treatment.mean - control.mean) / pooled_std
      where pooled_std = sqrt((treatment.std^2 + control.std^2) / 2)
    - 95% CI on the difference: diff ± 1.96 * SE
      where SE = sqrt(treatment.var/n_t + control.var/n_c)
    """
    raise NotImplementedError


def compute_required_sample_size(
    baseline_mean: float,
    baseline_std: float,
    mde: float,
    alpha: float = 0.05,
    power: float = 0.80,
) -> int:
    """
    Estimate the minimum sample size per group for a two-sample t-test.

    mde = minimum detectable effect (absolute, same units as baseline_mean)

    Formula:
        effect_size = mde / baseline_std
        n = 2 * ((z_alpha/2 + z_beta) / effect_size)^2

    Return an integer (ceil).
    """
    raise NotImplementedError


def summarize_pilot_results(
    pre_control: np.ndarray,
    post_control: np.ndarray,
    pre_treatment: np.ndarray,
    post_treatment: np.ndarray,
) -> dict:
    """
    Compute a Difference-in-Differences (DiD) estimate.

    DiD = (post_treatment.mean - pre_treatment.mean)
          - (post_control.mean - pre_control.mean)

    Use a bootstrap (n=2000, seed=42) to compute:
    - 95% CI: 2.5th and 97.5th percentiles of bootstrap distribution
    - Approximate p-value: fraction of bootstrap samples where
      abs(did) >= abs(observed did)

    Return a dict with keys:
        treatment_delta, control_delta, did_estimate,
        p_value_approx, ci_95 (tuple), significant (bool, threshold 0.05)
    """
    raise NotImplementedError


# ============================================================
# 3. ACCOUNT SEGMENTATION
# ============================================================

def segment_accounts(account_features: pd.DataFrame, n_clusters: int = 4) -> pd.DataFrame:
    """
    K-means segmentation of accounts on their numeric feature columns.

    Steps:
    1. Select all numeric columns
    2. StandardScaler normalize
    3. Fit KMeans (random_state=42, n_init=10)
    4. Add a 'segment' column with cluster labels (0-indexed integers)
    5. If 'avg_csat' is in the numeric columns, also add a 'segment_label'
       column: rank segments by avg_csat descending, label "Tier 1" (best) through "Tier N"

    Return the DataFrame with the new columns.
    """
    raise NotImplementedError


# ============================================================
# 4. BASIC NLP FOR CONVERSATIONAL DATA
# ============================================================

def clean_transcript(text: str) -> str:
    """
    Normalize a raw call transcript:
    1. Lowercase
    2. Remove speaker labels (e.g., "Agent:", "Customer:", "Rep:", "Caller:")
    3. Remove all non-alphabetic characters (keep spaces)
    4. Collapse multiple spaces to one and strip

    Return the cleaned string.
    """
    raise NotImplementedError


def extract_top_ngrams(
    transcripts: list[str],
    n: int = 2,
    top_k: int = 20,
    stopwords: set = None,
) -> list[tuple[str, int]]:
    """
    Extract the top_k most common n-grams across all transcripts.

    Steps:
    1. clean_transcript each transcript
    2. Tokenize, filter out stopwords and tokens shorter than 3 characters
    3. Build n-grams using zip(*[tokens[i:] for i in range(n)])
    4. Return Counter.most_common(top_k)

    Default stopwords (if None provided):
        {"i", "you", "we", "the", "a", "an", "is", "it", "to", "and",
         "that", "this", "of", "in", "for", "my", "your", "on", "at",
         "with", "can", "was", "are", "have", "do", "be", "so", "just"}
    """
    raise NotImplementedError


def rule_based_intent_classifier(transcript: str) -> str:
    """
    Classify a transcript into one of:
        escalation | cancellation | billing | technical | general

    Apply rules in the order listed above (first match wins).
    Keywords:
        escalation:   ["supervisor", "manager", "escalate", "unacceptable", "complaint"]
        cancellation: ["cancel", "cancellation", "close account", "stop service", "end my plan"]
        billing:      ["charge", "invoice", "bill", "payment", "refund", "overcharged"]
        technical:    ["not working", "error", "broken", "outage", "can't connect", "issue with"]

    Return "general" if no keywords match.
    """
    raise NotImplementedError


def compute_sentiment_score(transcript: str) -> float:
    """
    Lexicon-based sentiment score in [-1, 1].

    Positive words: {"great", "excellent", "helpful", "thank", "resolved",
                     "happy", "appreciate", "wonderful", "perfect", "love"}
    Negative words: {"terrible", "awful", "frustrated", "angry", "unacceptable",
                     "worst", "disappointed", "hate", "useless", "ridiculous"}

    Algorithm:
    1. clean_transcript the text, split into tokens, convert to a set
    2. pos_count = intersection with positive_words
    3. neg_count = intersection with negative_words
    4. score = (pos - neg) / (pos + neg), or 0.0 if total == 0

    Return rounded to 4 decimal places.
    """
    raise NotImplementedError


# ============================================================
# 5. REPORTED CRESTA INTERVIEW QUESTION: BALANCED CLASS SAMPLING
# This question was reported on Glassdoor for a Cresta technical screen.
# ============================================================

def balanced_sample_allocation(n: int, class_counts: list[int]) -> list[int]:
    """
    *** ACTUAL CRESTA INTERVIEW QUESTION ***

    Given a dataset with labeled classes, you want to randomly sample an
    n-element subset such that classes are as balanced as possible.

    Write a function which, given n and the number of examples in each class,
    computes how many examples should be sampled from each class.

    Args:
        n: total number of samples to draw
        class_counts: list of integers, where class_counts[i] is the number
                      of examples in class i

    Returns:
        list of integers, where result[i] is how many examples to sample
        from class i. sum(result) must equal n.

    Rules:
    - Never sample more from a class than it has available
    - Distribute as evenly as possible across classes
    - When even distribution isn't possible (some classes too small),
      allocate their max, then redistribute the remainder evenly among
      classes that still have capacity
    - Break ties by giving extra samples to earlier classes (lower index)

    Examples:
        balanced_sample_allocation(10, [5, 5, 5]) -> [4, 3, 3]
        balanced_sample_allocation(10, [3, 10, 10]) -> [3, 4, 3]
        balanced_sample_allocation(6, [1, 1, 100]) -> [1, 1, 4]
        balanced_sample_allocation(0, [5, 5]) -> [0, 0]
    """
    raise NotImplementedError


# ============================================================
# 6. CRESTA-SPECIFIC: AUTOMATION READINESS SCORING
# Mirrors the logic behind Cresta's Automation Discovery product
# ============================================================

def compute_automation_readiness(
    conversations_df: pd.DataFrame,
    outcomes_df: pd.DataFrame,
) -> pd.DataFrame:
    """
    Score each account's conversations for automation potential.

    Cresta's Automation Discovery product scores conversations by volume,
    complexity, and resolution into a readiness score with projected ROI.

    Given:
    - conversations_df: conversation_id, account_id, agent_id, started_at, ended_at, channel
    - outcomes_df: conversation_id, csat_score, resolved, transfer_count, abandon_flag

    For each account, compute:
    - weekly_volume: average conversations per week
    - avg_handle_time: average AHT in seconds
    - fcr_rate: fraction resolved on first contact (resolved=True)
    - transfer_rate: avg transfers per conversation
    - complexity_score: normalize AHT to 0-1 using min-max across accounts
      (lower AHT = lower complexity = higher automation potential)
    - readiness_score = (0.35 * norm_volume) + (0.35 * (1 - complexity_score)) + (0.30 * fcr_rate)
      where norm_volume is also min-max normalized

    Return a DataFrame with columns:
        account_id | weekly_volume | avg_handle_time | fcr_rate | transfer_rate |
        complexity_score | readiness_score

    Sorted by readiness_score descending.
    """
    raise NotImplementedError


# ============================================================
# 7. COACHING EFFECTIVENESS MEASUREMENT
# A core deliverable for the DS, Customer Analytics role
# ============================================================

def measure_coaching_effectiveness(
    conversations_df: pd.DataFrame,
    events_df: pd.DataFrame,
    outcomes_df: pd.DataFrame,
) -> dict:
    """
    Measure whether Cresta's coaching suggestions improve conversation outcomes.

    Given:
    - conversations_df: conversation_id, agent_id, started_at, ended_at
    - events_df: event_id, conversation_id, agent_id, event_type, occurred_at
    - outcomes_df: conversation_id, csat_score, resolved, transfer_count

    Steps:
    1. Split conversations into two groups:
       - coached: at least one 'coaching_suggestion' event
       - uncoached: zero 'coaching_suggestion' events
    2. For each group compute:
       - mean AHT (handle_time_sec from started_at/ended_at)
       - mean CSAT (from outcomes)
       - FCR rate (fraction resolved)
       - count of conversations
    3. Run Welch's t-test on AHT between the two groups
    4. Run Welch's t-test on CSAT between the two groups

    Return a dict with keys:
        coached_count, uncoached_count,
        coached_aht, uncoached_aht, aht_diff, aht_pvalue,
        coached_csat, uncoached_csat, csat_diff, csat_pvalue,
        coached_fcr, uncoached_fcr

    Round all floats to 4 decimal places.
    """
    raise NotImplementedError
