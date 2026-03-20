-- ============================================================
-- Cresta SQL Practice — Solutions
-- See schema.md for full table reference
-- ============================================================


-- ============================================================
-- SECTION 1: WARM-UP — Core Metrics
-- ============================================================

-- 1a. Average handle time per agent per week
-- DATEDIFF gives the duration in seconds; DATE_TRUNC floors to the week boundary.
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
-- ROW_NUMBER rather than RANK so ties don't push a 4th row through.
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


-- 1c. Accounts where CSAT dropped >10 points month-over-month
-- LAG lets us compare each month to the previous one within the same account.
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

-- 2a. Pre/post AHT comparison per account
-- Two CTEs define pre and post windows using pilot dates from the accounts table.
-- Watch out: BETWEEN is inclusive on both ends.
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


-- 2b. Treatment vs. control agent comparison
-- Pivot with conditional MAX to get side-by-side columns.
-- Note: this assumes each account has both enabled and non-enabled agents.
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
    MAX(CASE WHEN is_cresta_enabled     THEN avg_aht_sec END) AS treatment_aht,
    MAX(CASE WHEN NOT is_cresta_enabled THEN avg_aht_sec END) AS control_aht,
    MAX(CASE WHEN is_cresta_enabled     THEN avg_csat    END) AS treatment_csat,
    MAX(CASE WHEN NOT is_cresta_enabled THEN avg_csat    END) AS control_csat,
    MAX(CASE WHEN is_cresta_enabled     THEN fcr_rate    END) AS treatment_fcr,
    MAX(CASE WHEN NOT is_cresta_enabled THEN fcr_rate    END) AS control_fcr
FROM agent_metrics
GROUP BY 1;


-- ============================================================
-- SECTION 3: COHORT & RETENTION ANALYSIS
-- ============================================================

-- 3a. Agent cohort performance by hire month
-- DATE_TRUNC on hire_date groups agents into monthly cohorts.
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
    JOIN agents a         ON c.agent_id = a.agent_id
    JOIN agent_cohorts ac ON a.agent_id = ac.agent_id
    JOIN outcomes o       ON c.conversation_id = o.conversation_id
    GROUP BY 1, 2
)
SELECT *
FROM agent_weekly
ORDER BY cohort_month, week_start;


-- 3b. CSAT trajectory: first 26 weeks post go-live, aggregated across accounts
-- DATEDIFF in weeks gives the "week number" since launch.
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

-- 4a. Events per conversation by type
-- Dividing total events by distinct conversations gives average depth per call.
SELECT
    event_type,
    COUNT(*)                              AS total_events,
    COUNT(DISTINCT conversation_id)       AS conversations,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT conversation_id), 2) AS events_per_conversation
FROM conversation_events
GROUP BY 1
ORDER BY events_per_conversation DESC;


-- 4b. Conversations with no outcome record (data quality check)
-- LEFT JOIN + IS NULL is the standard pattern for finding unmatched rows.
SELECT
    c.conversation_id,
    c.agent_id,
    c.started_at
FROM conversations c
LEFT JOIN outcomes o ON c.conversation_id = o.conversation_id
WHERE o.conversation_id IS NULL
ORDER BY c.started_at DESC
LIMIT 100;


-- 4c. Weekly transfer rate trend
-- Transfer rate = total transfers / total conversations (not avg of per-call rates).
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

-- 5a. Peak week per account (window function approach)
-- RANK instead of ROW_NUMBER so tied peak weeks both surface.
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


-- 5b. Rolling 4-week average AHT
-- ROWS BETWEEN 3 PRECEDING AND CURRENT ROW = current row + 3 prior rows = 4 weeks total.
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


-- 5c. Accounts that improved AHT more than the median improvement
-- Step 1: use ROW_NUMBER + COUNT OVER to grab first and last row per account.
-- Step 2: compute % improvement. Step 3: filter vs. median via PERCENTILE_CONT.
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
            ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY week_start)  AS rn,
            COUNT(*)     OVER (PARTITION BY account_id)                       AS n
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
WHERE pct_improvement > (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pct_improvement) FROM with_delta
)
ORDER BY pct_improvement DESC;


-- ============================================================
-- SECTION 6: CRESTA-SPECIFIC SCENARIOS
-- ============================================================

-- 6a. Channel performance comparison
-- Straightforward GROUP BY with conditional aggregation across channels.
SELECT
    c.account_id,
    c.channel,
    COUNT(c.conversation_id)                                    AS call_volume,
    AVG(DATEDIFF('second', c.started_at, c.ended_at))          AS avg_aht_sec,
    AVG(o.csat_score)                                           AS avg_csat,
    AVG(CASE WHEN o.resolved THEN 1.0 ELSE 0.0 END)            AS fcr_rate
FROM conversations c
JOIN outcomes o ON c.conversation_id = o.conversation_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- 6b. Automation readiness scoring
-- MIN/MAX normalization across accounts, then weighted composite score.
-- The trick is using window functions for normalization inside a CTE.
WITH account_metrics AS (
    SELECT
        account_id,
        AVG(call_volume)                  AS avg_volume,
        AVG(avg_handle_time_sec)          AS avg_aht,
        AVG(first_call_resolution_rate)   AS fcr_rate
    FROM weekly_kpis
    GROUP BY 1
),
with_bounds AS (
    SELECT
        *,
        MIN(avg_volume) OVER () AS min_vol,  MAX(avg_volume) OVER () AS max_vol,
        MIN(avg_aht)    OVER () AS min_aht,  MAX(avg_aht)    OVER () AS max_aht,
        MIN(fcr_rate)   OVER () AS min_fcr,  MAX(fcr_rate)   OVER () AS max_fcr
    FROM account_metrics
),
normalized AS (
    SELECT
        account_id,
        avg_volume,
        avg_aht,
        fcr_rate,
        -- Normalize to 0-1
        (avg_volume - min_vol) / NULLIF(max_vol - min_vol, 0) AS norm_volume,
        (avg_aht    - min_aht) / NULLIF(max_aht - min_aht, 0) AS norm_aht,
        (fcr_rate   - min_fcr) / NULLIF(max_fcr - min_fcr, 0) AS norm_fcr
    FROM with_bounds
)
SELECT
    account_id,
    ROUND(avg_volume, 0)  AS avg_volume,
    ROUND(avg_aht, 0)     AS avg_aht,
    ROUND(fcr_rate, 3)    AS fcr_rate,
    ROUND((norm_volume + (1 - norm_aht) + norm_fcr) / 3, 3) AS readiness_score
FROM normalized
ORDER BY readiness_score DESC;


-- 6c. Coaching adoption rate by team
-- LEFT JOIN from conversations to coaching events, then aggregate by team.
WITH conv_coaching AS (
    SELECT
        a.team_id,
        c.conversation_id,
        MAX(CASE WHEN ce.event_type = 'coaching_suggestion' THEN 1 ELSE 0 END) AS was_coached
    FROM conversations c
    JOIN agents a ON c.agent_id = a.agent_id
    LEFT JOIN conversation_events ce
        ON c.conversation_id = ce.conversation_id
        AND ce.event_type = 'coaching_suggestion'
    GROUP BY 1, 2
)
SELECT
    team_id,
    COUNT(*)                          AS total_conversations,
    SUM(was_coached)                  AS coached_conversations,
    ROUND(SUM(was_coached) * 1.0 / COUNT(*), 3) AS coaching_rate,
    RANK() OVER (ORDER BY SUM(was_coached) * 1.0 / COUNT(*) DESC) AS team_rank
FROM conv_coaching
GROUP BY 1
ORDER BY team_rank;


-- 6d. Agent ramp curve by tenure bucket and Cresta status
-- CASE expression on DATEDIFF between hire_date and conversation date creates tenure buckets.
-- Side-by-side comparison is the core deliverable for proving "faster onboarding."
SELECT
    CASE
        WHEN DATEDIFF('month', a.hire_date, c.started_at) < 3  THEN '0-3 months'
        WHEN DATEDIFF('month', a.hire_date, c.started_at) < 6  THEN '3-6 months'
        WHEN DATEDIFF('month', a.hire_date, c.started_at) < 12 THEN '6-12 months'
        ELSE '12+ months'
    END                                                AS tenure_bucket,
    a.is_cresta_enabled,
    COUNT(DISTINCT a.agent_id)                         AS agent_count,
    AVG(DATEDIFF('second', c.started_at, c.ended_at)) AS avg_aht_sec,
    AVG(o.csat_score)                                  AS avg_csat
FROM conversations c
JOIN agents a   ON c.agent_id = a.agent_id
JOIN outcomes o ON c.conversation_id = o.conversation_id
GROUP BY 1, 2
ORDER BY
    CASE tenure_bucket
        WHEN '0-3 months'  THEN 1
        WHEN '3-6 months'  THEN 2
        WHEN '6-12 months' THEN 3
        ELSE 4
    END,
    a.is_cresta_enabled;


-- 6e. Multi-metric account health score
-- Split last 8 weeks into two halves, compute trend as % change, then weighted composite.
WITH last_8_weeks AS (
    SELECT
        account_id,
        week_start,
        avg_handle_time_sec,
        csat_avg,
        first_call_resolution_rate,
        ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY week_start DESC) AS rn
    FROM weekly_kpis
),
halves AS (
    SELECT
        account_id,
        AVG(CASE WHEN rn <= 4 THEN csat_avg END)                AS recent_csat,
        AVG(CASE WHEN rn BETWEEN 5 AND 8 THEN csat_avg END)     AS earlier_csat,
        AVG(CASE WHEN rn <= 4 THEN avg_handle_time_sec END)     AS recent_aht,
        AVG(CASE WHEN rn BETWEEN 5 AND 8 THEN avg_handle_time_sec END) AS earlier_aht,
        AVG(first_call_resolution_rate)                           AS avg_fcr
    FROM last_8_weeks
    WHERE rn <= 8
    GROUP BY account_id
),
trends AS (
    SELECT
        account_id,
        (recent_csat - earlier_csat) / NULLIF(earlier_csat, 0) AS csat_trend,
        (recent_aht  - earlier_aht)  / NULLIF(earlier_aht, 0)  AS aht_trend,
        avg_fcr
    FROM halves
    WHERE earlier_csat IS NOT NULL AND earlier_aht IS NOT NULL
)
SELECT
    account_id,
    ROUND(csat_trend, 4)  AS csat_trend,
    ROUND(aht_trend, 4)   AS aht_trend,
    ROUND(avg_fcr, 3)     AS avg_fcr,
    ROUND((csat_trend * 0.4) + (aht_trend * -0.3) + (avg_fcr * 0.3), 4) AS health_score
FROM trends
ORDER BY health_score DESC;
