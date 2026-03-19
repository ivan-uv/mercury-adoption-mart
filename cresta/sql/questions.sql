-- ============================================================
-- Cresta SQL Practice — Questions
-- See schema.md for full table reference
-- Solutions in solutions.sql
-- ============================================================


-- ============================================================
-- SECTION 1: WARM-UP — Core Metrics
-- ============================================================

-- 1a. Average handle time per agent per week
-- Handle time = seconds from conversation start to end
-- Expected output: agent_id | week_start | call_volume | avg_handle_time_sec


-- YOUR QUERY HERE


-- ---------------------------------------------------------------

-- 1b. Top 3 agents by call volume per region, last 30 days
-- Hint: window functions


-- YOUR QUERY HERE


-- ---------------------------------------------------------------

-- 1c. Flag accounts whose average CSAT dropped more than 10 points month-over-month
-- Expected output: account_id | month | prev_month_csat | current_csat | csat_delta


-- YOUR QUERY HERE


-- ============================================================
-- SECTION 2: PILOT MEASUREMENT
-- ============================================================

-- 2a. Pre/post AHT comparison per account during their pilot window
-- Pre-period = 8 weeks before pilot_start_date
-- Post-period = between pilot_start_date and pilot_end_date
-- Expected output: account_id | pre_aht_sec | post_aht_sec | pct_change


-- YOUR QUERY HERE


-- ---------------------------------------------------------------

-- 2b. Treatment vs. control agent comparison within each account
-- Cresta-enabled agents = treatment group
-- Expected output: one row per account with side-by-side AHT, CSAT, FCR for each group


-- YOUR QUERY HERE


-- ============================================================
-- SECTION 3: COHORT & RETENTION ANALYSIS
-- ============================================================

-- 3a. Agent cohort performance
-- Group agents by hire month (cohort), then compute weekly call volume, AHT, and CSAT
-- Expected output: cohort_month | week_start | call_volume | avg_aht_sec | avg_csat


-- YOUR QUERY HERE


-- ---------------------------------------------------------------

-- 3b. CSAT trajectory for the first 26 weeks after each account's Cresta go-live
-- Expected output: weeks_since_golive | accounts | avg_csat | stddev_csat


-- YOUR QUERY HERE


-- ============================================================
-- SECTION 4: CONVERSATIONAL DATA
-- ============================================================

-- 4a. Average number of events per conversation, broken out by event_type
-- Higher event count = proxy for complexity or coaching activity
-- Expected output: event_type | total_events | conversations | events_per_conversation


-- YOUR QUERY HERE


-- ---------------------------------------------------------------

-- 4b. Data quality check: find conversations that have no matching outcome record


-- YOUR QUERY HERE


-- ---------------------------------------------------------------

-- 4c. Weekly transfer rate trend
-- transfer_rate = total transfers / total conversations
-- High transfer rate = bad CX signal
-- Expected output: week_start | total_conversations | total_transfers | avg_transfers_per_call | transfer_rate


-- YOUR QUERY HERE


-- ============================================================
-- SECTION 5: TRICKY / INTERVIEW-STYLE PROBLEMS
-- ============================================================

-- 5a. For each account, return only the week with the highest call volume
-- Constraint: use window functions — do NOT use GROUP BY + MAX in a subquery


-- YOUR QUERY HERE


-- ---------------------------------------------------------------

-- 5b. Rolling 4-week average AHT per account
-- Expected output includes both the raw weekly value and the rolling average alongside it


-- YOUR QUERY HERE


-- ---------------------------------------------------------------

-- 5c. Find accounts that improved AHT more than the median improvement
-- "Improvement" = % reduction from first recorded week to last recorded week
-- Hint: you'll need ROW_NUMBER, COUNT(*) OVER, and PERCENTILE_CONT


-- YOUR QUERY HERE
