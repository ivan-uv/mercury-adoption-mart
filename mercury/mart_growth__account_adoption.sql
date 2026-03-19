-- models/marts/mart_growth__account_adoption.sql
--
-- PURPOSE: Monthly snapshot fact table tracking product adoption state per account.
-- GRAIN:   One row per account_id × snapshot_month.
-- USERS:   
--   • Data Scientists — propensity model feature store (next-product prediction)
--   • Growth/Product — self-serve activation dashboards in Omni/Hex
--   • Ops/AM teams  — account health monitoring and cross-sell prioritization
--
-- DESIGN NOTES:
--   Incremental by snapshot_month to support large account volumes efficiently.
--   Full refresh on schema changes. Unique key = account_id + snapshot_month.
--   RLS policy applied at the schema level (not here) for compliance segmentation.

{{
    config(
        materialized='incremental',
        unique_key=['account_id', 'snapshot_month'],
        incremental_strategy='merge',
        cluster_by=['snapshot_month', 'industry_segment'],
        on_schema_change='sync_all_columns'
    )
}}

with spine as (
    -- Generate one record per account per calendar month since opening.
    -- Stops at current month; historical months are never re-processed after merge.
    select
        a.account_id,
        date_trunc('month', m.month_start)::date as snapshot_month
    from {{ ref('stg_accounts') }} a
    -- Cross join with a date spine (dbt-utils or a warehouse calendar table)
    cross join (
        select dateadd('month', seq4(), date_trunc('month', '2021-01-01'::date)) as month_start
        from table(generator(rowcount => 60))   -- covers 5 years; extend as needed
    ) m
    where m.month_start <= date_trunc('month', current_date)
      and m.month_start >= date_trunc('month', a.opened_at)
    {% if is_incremental() %}
      -- Only process the current month on incremental runs
      and m.month_start = date_trunc('month', current_date)
    {% endif %}
),

health as (
    select * from {{ ref('int_account_health_signals') }}
),

accounts as (
    select * from {{ ref('stg_accounts') }}
),

final as (
    select
        -- Keys
        s.account_id,
        s.snapshot_month,

        -- Account dimensions (slowly changing: pulled fresh each run)
        a.business_id,
        a.industry_segment,
        a.account_type,
        a.partner_bank,
        a.account_status,
        a.is_active,

        -- Cohort dimensions (immutable after account open)
        date_trunc('month', a.opened_at)::date          as cohort_month,
        datediff('month', a.opened_at, s.snapshot_month) as account_age_months,

        case
            when datediff('month', a.opened_at, s.snapshot_month) between 0 and 2  then '0-2m'
            when datediff('month', a.opened_at, s.snapshot_month) between 3 and 5  then '3-5m'
            when datediff('month', a.opened_at, s.snapshot_month) between 6 and 11 then '6-11m'
            else '12m+'
        end                                             as account_age_band,

        -- Adoption facts (point-in-time as of snapshot_month)
        h.products_enrolled,
        h.products_active_30d,
        h.products_dormant,
        h.revenue_products_enrolled,
        h.product_breadth_score,

        -- Product flags
        h.has_checking,
        h.has_credit_card,
        h.has_treasury,
        h.has_loan,
        h.has_bill_pay,
        h.has_invoicing,

        -- Engagement facts
        h.lifetime_volume_usd,
        h.volume_last_30d_usd,
        h.avg_days_to_first_use,
        a.days_to_first_deposit,

        -- Cross-sell intelligence (feeds agentic workflow triggers)
        h.recommended_next_product,

        -- Audit
        current_timestamp                               as dbt_updated_at

    from spine s
    inner join accounts a using (account_id)
    left join health h using (account_id)
)

select * from final
