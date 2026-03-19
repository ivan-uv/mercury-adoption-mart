-- ============================================================
-- Cresta SQL Practice — Questions
-- See schema.md for full table reference
-- Solutions in solutions.sql
-- ============================================================


-- ============================================================
-- SAMPLE DATA (for reference while solving)
-- ============================================================

-- accounts
-- account_id  | account_name | industry            | pilot_start_date | pilot_end_date | contract_arr
-- acc_001     | Intuit       | financial_services  | 2024-01-08       | 2024-03-31     | 1200000
-- acc_002     | Cox Comms    | telecom             | 2024-02-05       | 2024-04-28     |  850000
-- acc_003     | Hilton       | hospitality         | 2024-03-11       | NULL           |  640000

-- agents
-- agent_id  | account_id | hire_date  | region | team_id  | is_cresta_enabled
-- agt_001   | acc_001    | 2022-06-01 | AMER   | team_A   | true
-- agt_002   | acc_001    | 2023-01-15 | AMER   | team_A   | false
-- agt_003   | acc_002    | 2021-11-20 | EMEA   | team_B   | true
-- agt_004   | acc_003    | 2024-01-03 | APAC   | team_C   | true

-- conversations
-- conversation_id | agent_id | account_id | started_at          | ended_at            | channel
-- conv_0001       | agt_001  | acc_001    | 2024-02-01 09:04:11 | 2024-02-01 09:11:38 | phone
-- conv_0002       | agt_002  | acc_001    | 2024-02-01 09:15:00 | 2024-02-01 09:27:45 | chat
-- conv_0003       | agt_003  | acc_002    | 2024-02-01 10:02:33 | 2024-02-01 10:09:01 | phone
-- conv_0004       | agt_001  | acc_001    | 2024-02-01 10:30:00 | 2024-02-01 10:36:20 | phone
--   → agt_001 handle times: 447s, 380s  |  agt_002: 765s

-- outcomes
-- conversation_id | csat_score | resolved | transfer_count | abandon_flag
-- conv_0001       | 4.5        | true     | 0              | false
-- conv_0002       | 2.0        | false    | 1              | false
-- conv_0003       | 5.0        | true     | 0              | false
-- conv_0004       | NULL       | true     | 0              | false   ← no CSAT submitted
--   (conv_0002 has no outcome row at all — intentional gap for Q4b)

-- conversation_events
-- event_id   | conversation_id | agent_id | event_type           | occurred_at
-- evt_00001  | conv_0001       | agt_001  | coaching_suggestion  | 2024-02-01 09:05:30
-- evt_00002  | conv_0001       | agt_001  | script_deviation      | 2024-02-01 09:08:00
-- evt_00003  | conv_0003       | agt_003  | coaching_suggestion  | 2024-02-01 10:03:15
-- evt_00004  | conv_0004       | agt_001  | hold_start           | 2024-02-01 10:32:00

-- weekly_kpis
-- account_id | week_start | avg_handle_time_sec | csat_avg | first_call_resolution_rate | call_volume
-- acc_001    | 2024-01-08 | 431.2               | 3.8      | 0.71                       | 312
-- acc_001    | 2024-01-15 | 418.6               | 3.9      | 0.74                       | 298
-- acc_001    | 2024-01-22 | 402.1               | 4.1      | 0.77                       | 341
-- acc_002    | 2024-01-08 | 385.0               | 4.4      | 0.83                       | 187
-- acc_002    | 2024-01-15 | 390.3               | 4.2      | 0.81                       | 203
--   → acc_001 AHT is trending down after pilot start (2024-01-08)


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
