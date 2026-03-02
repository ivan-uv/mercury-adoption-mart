-- models/intermediate/int_account_product_activity.sql
-- For each account × product combination, compute activity signals.
-- Ephemeral: used only as a building block; not persisted to warehouse.
-- Downstream consumers: mart_growth__account_adoption, propensity feature stores.

with enrollments as (
    select * from {{ ref('stg_product_enrollments') }}
    where is_currently_enrolled = true
),

transactions as (
    select * from {{ ref('stg_transactions') }}
    where is_completed = true
),

-- Aggregate transaction activity per account × product
txn_signals as (
    select
        account_id,
        product_slug,
        min(transacted_at)                                          as first_transaction_at,
        max(transacted_at)                                          as last_transaction_at,
        count(distinct transaction_id)                              as total_transactions,
        sum(amount_usd)                                             as total_volume_usd,

        -- recency activity flags (relative to current date for incremental freshness)
        count_if(transacted_date >= current_date - 30)              as txns_last_30d,
        count_if(transacted_date >= current_date - 60)              as txns_last_60d,
        count_if(transacted_date >= current_date - 90)              as txns_last_90d,

        sum(case when transacted_date >= current_date - 30 then amount_usd else 0 end) as volume_last_30d_usd

    from transactions
    group by 1, 2
),

-- Join enrollments with activity
joined as (
    select
        e.account_id,
        e.product_slug,
        e.enrolled_at,

        t.first_transaction_at,
        t.last_transaction_at,
        t.total_transactions,
        t.total_volume_usd,
        t.txns_last_30d,
        t.txns_last_60d,
        t.txns_last_90d,
        t.volume_last_30d_usd,

        -- days from enrollment to first use (adoption lag — key propensity feature)
        datediff('day', e.enrolled_at, t.first_transaction_at)      as days_enrollment_to_first_use,

        -- active = used in last 30 days
        case when t.txns_last_30d > 0 then true else false end       as is_active_30d,

        -- dormant = enrolled but never transacted
        case when t.first_transaction_at is null then true else false end as is_dormant

    from enrollments e
    left join txn_signals t
        on e.account_id = t.account_id
        and e.product_slug = t.product_slug
)

select * from joined
