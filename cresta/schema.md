# Data Schema Reference

This schema models a contact center analytics environment — the kind of data you'd work with at Cresta. Six tables cover the full lifecycle from account setup through individual conversation events and outcomes.

---

## Entity Relationship Overview

```
accounts ──────────────────────────────────────────┐
    │                                               │
    │ (1:many)                                      │
    ▼                                               ▼
agents ──────────────┐                        weekly_kpis
    │                │
    │ (1:many)        │ (1:many)
    ▼                ▼
conversations ──────────────────► outcomes
    │
    │ (1:many)
    ▼
conversation_events
```

---

## Tables

### `accounts`
One row per customer company. The top-level entity — everything rolls up here.

| Column | Type | Description |
|--------|------|-------------|
| `account_id` | `VARCHAR` | Primary key |
| `account_name` | `VARCHAR` | Company name (e.g., "Intuit", "Cox Communications") |
| `industry` | `VARCHAR` | Vertical (e.g., `financial_services`, `telecom`, `hospitality`) |
| `pilot_start_date` | `DATE` | When Cresta went live for this account |
| `pilot_end_date` | `DATE` | End of formal pilot window (NULL if ongoing) |
| `contract_arr` | `FLOAT` | Annual recurring revenue in USD |

**Common query patterns:** filter pilot cohorts, join to agent/KPI data for pre/post analysis.

---

### `agents`
One row per agent. Each agent belongs to exactly one account.

| Column | Type | Description |
|--------|------|-------------|
| `agent_id` | `VARCHAR` | Primary key |
| `account_id` | `VARCHAR` | FK → `accounts.account_id` |
| `hire_date` | `DATE` | Used to build tenure cohorts |
| `region` | `VARCHAR` | Geographic region (e.g., `AMER`, `EMEA`) |
| `team_id` | `VARCHAR` | Sub-team within an account |
| `is_cresta_enabled` | `BOOLEAN` | Whether this agent has Cresta active — used to define treatment/control groups |

**Common query patterns:** cohort by `hire_date`, split treatment/control via `is_cresta_enabled`, aggregate by `region` or `team_id`.

---

### `conversations`
One row per customer interaction (phone call or chat). The central fact table.

| Column | Type | Description |
|--------|------|-------------|
| `conversation_id` | `VARCHAR` | Primary key |
| `agent_id` | `VARCHAR` | FK → `agents.agent_id` |
| `account_id` | `VARCHAR` | FK → `accounts.account_id` (denormalized for query convenience) |
| `started_at` | `TIMESTAMP` | Conversation start time |
| `ended_at` | `TIMESTAMP` | Conversation end time |
| `channel` | `VARCHAR` | Interaction channel: `phone`, `chat`, `email` |

**Derived metric:** `handle_time_sec = DATEDIFF('second', started_at, ended_at)`

**Common query patterns:** join to `agents` for regional/cohort breakdowns, join to `outcomes` for quality metrics, group by `DATE_TRUNC('week', started_at)` for trend analysis.

---

### `outcomes`
One row per conversation — quality and resolution metrics captured after the interaction ends. Relates 1:1 with `conversations` (though not every conversation is guaranteed to have a record — intentional data quality gap for practice).

| Column | Type | Description |
|--------|------|-------------|
| `conversation_id` | `VARCHAR` | PK and FK → `conversations.conversation_id` |
| `csat_score` | `FLOAT` | Customer satisfaction score, typically 1–5 |
| `resolved` | `BOOLEAN` | Whether the issue was resolved on this call |
| `transfer_count` | `INTEGER` | Number of times the call was transferred |
| `abandon_flag` | `BOOLEAN` | True if the customer hung up before resolution |

**Derived metrics:**
- First call resolution (FCR): `AVG(CASE WHEN resolved THEN 1.0 ELSE 0.0 END)`
- Transfer rate: `SUM(transfer_count) / COUNT(*)`

---

### `conversation_events`
Event log — one row per discrete event within a conversation. Captures coaching triggers, suggested responses, holds, escalation requests, etc.

| Column | Type | Description |
|--------|------|-------------|
| `event_id` | `VARCHAR` | Primary key |
| `conversation_id` | `VARCHAR` | FK → `conversations.conversation_id` |
| `agent_id` | `VARCHAR` | FK → `agents.agent_id` (denormalized) |
| `event_type` | `VARCHAR` | Event category (e.g., `coaching_suggestion`, `hold_start`, `transfer_initiated`, `script_deviation`) |
| `occurred_at` | `TIMESTAMP` | When the event fired |

**Common query patterns:** count events per conversation as a proxy for complexity or coaching activity, time-series analysis of event frequency, filter by `event_type` to measure specific behaviors.

---

### `weekly_kpis`
Pre-aggregated weekly summary per account. A convenience table — think of it as a mart that's been pre-built so you don't have to re-aggregate raw conversations for every dashboard query.

| Column | Type | Description |
|--------|------|-------------|
| `account_id` | `VARCHAR` | FK → `accounts.account_id` |
| `week_start` | `DATE` | Monday of the week (grain: account × week) |
| `avg_handle_time_sec` | `FLOAT` | Average AHT across all conversations that week |
| `csat_avg` | `FLOAT` | Average CSAT score for the week |
| `first_call_resolution_rate` | `FLOAT` | FCR as a fraction (0–1) |
| `call_volume` | `INTEGER` | Total conversations handled |

**Composite PK:** `(account_id, week_start)`

**Common query patterns:** trend analysis, rolling averages, month-over-month comparisons, pre/post pilot measurement at the account level.

---

## Key Relationships at a Glance

| Relationship | Type | Join |
|---|---|---|
| account → agents | 1:many | `agents.account_id = accounts.account_id` |
| account → weekly_kpis | 1:many | `weekly_kpis.account_id = accounts.account_id` |
| agent → conversations | 1:many | `conversations.agent_id = agents.agent_id` |
| conversation → outcomes | 1:1 | `outcomes.conversation_id = conversations.conversation_id` |
| conversation → events | 1:many | `conversation_events.conversation_id = conversations.conversation_id` |

---

## Intentional Data Quality Gaps (for practice)

- Not every `conversation_id` has a matching row in `outcomes` — use this for LEFT JOIN / data quality exercises (see SQL Q4b)
- `pilot_end_date` can be NULL for active accounts — handle in WHERE clauses
- `transfer_count` can be 0 (no transfers) but not NULL — safe to SUM directly
