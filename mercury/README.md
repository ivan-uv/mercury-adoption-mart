# Mercury Product Adoption Mart

A dbt project demonstrating a dimensional data mart for tracking product adoption across Mercury's business account base.

Built as a portfolio piece for a Senior Analytics Engineering application. The design reflects real patterns from financial services analytics — specifically cross-sell signal modeling across multi-product platforms.

---

## What this models

Mercury serves 300K+ business customers across checking, savings, credit cards, treasury, lending, bill pay, and invoicing. Understanding *which accounts are using which products, how deeply, and what to offer next* is core to growth analytics.

This mart provides:

- **Monthly adoption snapshots** per account — who has what, when they adopted it, how active they are
- **Cross-sell signals** — rule-based `recommended_next_product` as a propensity model baseline
- **Engagement depth features** — volume, recency, days-to-first-use, product breadth score
- **Downstream-ready design** — built for both self-serve dashboards (Omni/Hex) and Data Science feature stores

---

## Project structure

```
models/
├── staging/
│   ├── stg_accounts.sql              # Account metadata & lifecycle state
│   ├── stg_product_enrollments.sql   # Account × product enrollment events
│   └── stg_transactions.sql          # Completed transactions (adoption signals)
├── intermediate/
│   ├── int_account_product_activity.sql  # Activity signals per account × product
│   └── int_account_health_signals.sql    # Rolled-up account-level health & cross-sell
└── marts/
    └── mart_growth__account_adoption.sql # Monthly snapshot fact table (incremental)

models/schema.yml                     # Tests & documentation for all models
dbt_project.yml                       # Project config (Snowflake target)
```

---

## DAG

```
stg_accounts ─────────────────────────────────────────────┐
                                                           ▼
stg_product_enrollments ──► int_account_product_activity ──► int_account_health_signals ──► mart_growth__account_adoption
                                                           ▲
stg_transactions ─────────────────────────────────────────┘
```

---

## Key design decisions

**Incremental merge on `account_id + snapshot_month`**  
Current-month-only incremental runs keep processing costs low on large account volumes. Full refresh triggered on schema change via `on_schema_change='sync_all_columns'`.

**Ephemeral intermediate models**  
`int_` models are ephemeral — they're logic containers, not persisted tables. This keeps the warehouse clean while enabling reuse across marts.

**Separation of concerns across layers**  
- `stg_` = source fidelity + basic typing. No business logic.  
- `int_` = business logic + joins. No presentation concern.  
- `mart_` = audience-shaped output. No raw joins.

**`recommended_next_product` as a baseline, not a final answer**  
The rule-based cross-sell field mirrors the logic used historically in Square AM workflows — accounts with checking but no credit card, high-volume accounts without treasury, etc. It's designed to be *replaced or augmented* by a Data Science propensity model, not to compete with one.

**Cluster keys on `snapshot_month` + `industry_segment`**  
Supports the most common query patterns: cohort analysis by month and segment-level funnel reporting.

---

## Testing approach

Tests defined in `schema.yml`:

- `unique` + `not_null` on all primary keys
- `relationships` tests enforce referential integrity across staging models
- `accepted_values` on all categorical dimensions (account type, status, product slugs)
- `dbt_utils.expression_is_true` for business rule validation (e.g., `amount_usd >= 0`)
- `dbt_utils.unique_combination_of_columns` on the mart's composite grain

---

## What I'd build next

1. **Near-real-time layer**: Snowflake Dynamic Tables (or Kafka → NiFi) for same-day activation signals — enabling agentic workflows to trigger on account state changes within hours, not days.

2. **Row-level security**: Column-level policies in Snowflake to gate sensitive financial fields by team role, supporting Mercury's compliance posture ahead of the bank charter.

3. **Exposure definitions**: dbt exposures linking the mart to its Omni dashboards and Data Science notebooks — making lineage queryable and impact analysis automatic.

4. **`mart_growth__cohort_retention`**: A companion cohort model tracking 30/60/90d product retention by cohort month and segment, feeding acquisition efficiency analysis.

---

## Stack assumptions

- **Warehouse**: Snowflake
- **Transformation**: dbt Core / dbt Cloud
- **Orchestration**: Airflow (or dbt Cloud scheduler)
- **Ingestion**: Fivetran
- **BI**: Omni / Hex
- **Additional utils**: `dbt_utils` package

---

*Built by Ivan Urena-Valdes - ivanurenavaldes@gmail.com — [linkedin.com/in/ivanurenavaldes](linkedin.com/in/ivanurenavaldes/)*
