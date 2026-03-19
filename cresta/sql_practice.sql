-- ============================================================
-- Cresta SQL Practice
-- Context: Contact center analytics — agents, conversations,
-- outcomes, pilot measurement
-- ============================================================


-- ============================================================
-- SCHEMA REFERENCE
-- ============================================================
-- conversations (conversation_id, agent_id, account_id, started_at, ended_at, channel)
-- conversation_events (event_id, conversation_id, agent_id, event_type, occurred_at)
-- outcomes (conversation_id, csat_score, resolved, transfer_count, abandon_flag)
-- agents (agent_id, account_id, hire_date, region, team_id, is_cresta_enabled)
-- accounts (account_id, account_name, industry, pilot_start_date, pilot_end_date, contract_arr)
-- weekly_kpis (account_id, week_start, avg_handle_time_sec, csat_avg, first_call_resolution_rate, call_volume)


-- ============================================================
-- SECTION 1: WARM-UP — Core Metrics
-- ============================================================

-- 1a. Average handle time per agent per week
-- Handle time = seconds from conversation start to end
SELECT
    a.agent_id,
    DATE_TRUNC('week', c.started_at) AS week_start,
    COUNT(c.conversation_id)         AS call_volume,
    AVG(DATEDIFF('second', c.started_at, c.ended_at)) AS avg_handle_time_sec
FROM conversations c
JOIN agents a ON c.agent_id = a.agent_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- 1b. Top 3 agents by call volume per region, last 30 days
WITH agent_volume AS (
    SELECT
        a.region,
        a.agent_id,
        COUNT(c.conversation_id) AS call_volume,
        ROW_NUMBER() OVER (PARTITION BY a.region ORDER BY COUNT(c.conversation_id) DESC) AS rk
    FROM conversations c
    JOIN agents a ON c.agent_id = a.agent_id
    WHERE c.started_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1, 2
)
SELECT region, agent_id, call_volume
FROM agent_volume
WHERE rk <= 3
ORDER BY region, call_volume DESC;


-- 1c. CSAT accounts that dropped >10 points month-over-month
WITH monthly_csat AS (
    SELECT
        account_id,
        DATE_TRUNC('month', week_start) AS month,
        AVG(csat_avg)                   AS csat
    FROM weekly_kpis
    GROUP BY 1, 2
),
with_lag AS (
    SELECT
        account_id,
        month,
        csat,
        LAG(csat) OVER (PARTITION BY account_id ORDER BY month) AS prev_csat
    FROM monthly_csat
)
SELECT
    account_id,
    month,
    ROUND(prev_csat, 2) AS prev_month_csat,
    ROUND(csat, 2)      AS current_csat,
    ROUND(csat - prev_csat, 2) AS csat_delta
FROM with_lag
WHERE (csat - prev_csat) < -10
ORDER BY csat_delta;


-- ============================================================
-- SECTION 2: PILOT MEASUREMENT
-- ============================================================

-- 2a. Pre/post comparison: AHT change per account during pilot
-- Assumes pilot_start_date is defined in accounts table
WITH pre_pilot AS (
    SELECT
        w.account_id,
        AVG(w.avg_handle_time_sec) AS pre_aht
    FROM weekly_kpis w
    JOIN accounts a ON w.account_id = a.account_id
    WHERE w.week_start BETWEEN (a.pilot_start_date - INTERVAL '8 weeks') AND a.pilot_start_date
    GROUP BY 1
),
post_pilot AS (
    SELECT
        w.account_id,
        AVG(w.avg_handle_time_sec) AS post_aht
    FROM weekly_kpis w
    JOIN accounts a ON w.account_id = a.account_id
    WHERE w.week_start BETWEEN a.pilot_start_date AND a.pilot_end_date
    GROUP BY 1
)
SELECT
    pre.account_id,
    ROUND(pre.pre_aht, 0)  AS pre_aht_sec,
    ROUND(post.post_aht, 0) AS post_aht_sec,
    ROUND((post.post_aht - pre.pre_aht) / pre.pre_aht * 100, 1) AS pct_change
FROM pre_pilot pre
JOIN post_pilot post ON pre.account_id = post.account_id
ORDER BY pct_change;


-- 2b. Treatment vs. control agent comparison (within an account)
-- Cresta-enabled agents = treatment, others = control
WITH agent_metrics AS (
    SELECT
        a.account_id,
        a.is_cresta_enabled,
        COUNT(c.conversation_id)                                    AS call_volume,
        AVG(DATEDIFF('second', c.started_at, c.ended_at))          AS avg_aht_sec,
        AVG(o.csat_score)                                           AS avg_csat,
        AVG(CASE WHEN o.resolved THEN 1.0 ELSE 0.0 END)            AS fcr_rate
    FROM conversations c
    JOIN agents a       ON c.agent_id = a.agent_id
    JOIN outcomes o     ON c.conversation_id = o.conversation_id
    WHERE c.started_at >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY 1, 2
)
SELECT
    account_id,
    MAX(CASE WHEN is_cresta_enabled THEN avg_aht_sec END)  AS treatment_aht,
    MAX(CASE WHEN NOT is_cresta_enabled THEN avg_aht_sec END) AS control_aht,
    MAX(CASE WHEN is_cresta_enabled THEN avg_csat END)     AS treatment_csat,
    MAX(CASE WHEN NOT is_cresta_enabled THEN avg_csat END) AS control_csat,
    MAX(CASE WHEN is_cresta_enabled THEN fcr_rate END)     AS treatment_fcr,
    MAX(CASE WHEN NOT is_cresta_enabled THEN fcr_rate END) AS control_fcr
FROM agent_metrics
GROUP BY 1;


-- ============================================================
-- SECTION 3: COHORT & RETENTION ANALYSIS
-- ============================================================

-- 3a. Agent cohort performance — group agents by hire month, compare KPIs
WITH agent_cohorts AS (
    SELECT
        agent_id,
        DATE_TRUNC('month', hire_date) AS cohort_month
    FROM agents
),
agent_weekly AS (
    SELECT
        ac.cohort_month,
        DATE_TRUNC('week', c.started_at) AS week_start,
        COUNT(c.conversation_id)         AS call_volume,
        AVG(DATEDIFF('second', c.started_at, c.ended_at)) AS avg_aht_sec,
        AVG(o.csat_score)                AS avg_csat
    FROM conversations c
    JOIN agents a     ON c.agent_id = a.agent_id
    JOIN agent_cohorts ac ON a.agent_id = ac.agent_id
    JOIN outcomes o   ON c.conversation_id = o.conversation_id
    GROUP BY 1, 2
)
SELECT *
FROM agent_weekly
ORDER BY cohort_month, week_start;


-- 3b. Account tenure cohort: CSAT trajectory in first 6 months after Cresta go-live
WITH cohort_weeks AS (
    SELECT
        w.account_id,
        w.week_start,
        w.csat_avg,
        DATEDIFF('week', a.pilot_start_date, w.week_start) AS weeks_since_golive
    FROM weekly_kpis w
    JOIN accounts a ON w.account_id = a.account_id
    WHERE w.week_start >= a.pilot_start_date
)
SELECT
    weeks_since_golive,
    COUNT(DISTINCT account_id) AS accounts,
    ROUND(AVG(csat_avg), 2)   AS avg_csat,
    ROUND(STDDEV(csat_avg), 2) AS stddev_csat
FROM cohort_weeks
WHERE weeks_since_golive BETWEEN 0 AND 26
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- SECTION 4: CONVERSATIONAL DATA
-- ============================================================

-- 4a. Average events per conversation by event type
-- (Proxy for conversation complexity / coaching touchpoints)
SELECT
    event_type,
    COUNT(*)                              AS total_events,
    COUNT(DISTINCT conversation_id)       AS conversations,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT conversation_id), 2) AS events_per_conversation
FROM conversation_events
GROUP BY 1
ORDER BY events_per_conversation DESC;


-- 4b. Find conversations with no outcome record (data quality check)
SELECT
    c.conversation_id,
    c.agent_id,
    c.started_at
FROM conversations c
LEFT JOIN outcomes o ON c.conversation_id = o.conversation_id
WHERE o.conversation_id IS NULL
ORDER BY c.started_at DESC
LIMIT 100;


-- 4c. Transfer rate trend by week — high transfers = bad CX signal
SELECT
    DATE_TRUNC('week', c.started_at) AS week_start,
    COUNT(c.conversation_id)          AS total_conversations,
    SUM(o.transfer_count)             AS total_transfers,
    ROUND(AVG(o.transfer_count), 3)   AS avg_transfers_per_call,
    ROUND(SUM(o.transfer_count) * 1.0 / COUNT(c.conversation_id), 3) AS transfer_rate
FROM conversations c
JOIN outcomes o ON c.conversation_id = o.conversation_id
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- SECTION 5: TRICKY / INTERVIEW-STYLE PROBLEMS
-- ============================================================

-- 5a. For each account, find the week with the highest call volume
-- Use window functions — do NOT use a subquery with GROUP BY + MAX hack
WITH ranked_weeks AS (
    SELECT
        account_id,
        week_start,
        call_volume,
        RANK() OVER (PARTITION BY account_id ORDER BY call_volume DESC) AS rk
    FROM weekly_kpis
)
SELECT account_id, week_start, call_volume
FROM ranked_weeks
WHERE rk = 1;


-- 5b. Rolling 4-week average AHT per account
SELECT
    account_id,
    week_start,
    avg_handle_time_sec,
    AVG(avg_handle_time_sec) OVER (
        PARTITION BY account_id
        ORDER BY week_start
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ) AS rolling_4wk_aht
FROM weekly_kpis
ORDER BY account_id, week_start;


-- 5c. Self-join: find accounts whose AHT improved more than the median improvement
-- (Two-step: compute improvement per account, then compare to median)
WITH improvements AS (
    SELECT
        account_id,
        MAX(CASE WHEN rn = 1 THEN avg_handle_time_sec END) AS first_week_aht,
        MAX(CASE WHEN rn = n THEN avg_handle_time_sec END) AS last_week_aht
    FROM (
        SELECT
            account_id,
            week_start,
            avg_handle_time_sec,
            ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY week_start)     AS rn,
            COUNT(*) OVER (PARTITION BY account_id)                              AS n
        FROM weekly_kpis
    ) t
    GROUP BY account_id
),
with_delta AS (
    SELECT
        account_id,
        first_week_aht,
        last_week_aht,
        (first_week_aht - last_week_aht) / first_week_aht AS pct_improvement
    FROM improvements
    WHERE first_week_aht IS NOT NULL AND last_week_aht IS NOT NULL
)
SELECT *
FROM with_delta
WHERE pct_improvement > (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pct_improvement) FROM with_delta)
ORDER BY pct_improvement DESC;
