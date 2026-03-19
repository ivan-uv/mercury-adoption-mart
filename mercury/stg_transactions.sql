-- models/staging/stg_transactions.sql
-- One row per transaction. Scoped to signals relevant to product adoption
-- (not a full ledger model — that lives in the finance domain).

with source as (
    select * from {{ source('mercury_raw', 'transactions') }}
),

renamed as (
    select
        transaction_id,
        account_id,
        lower(trim(transaction_type))   as transaction_type,   -- 'ach', 'wire', 'card', 'internal_transfer', etc.
        lower(trim(product_slug))       as product_slug,       -- which Mercury product generated this txn
        lower(trim(status))             as status,             -- 'completed', 'pending', 'failed', 'reversed'

        amount_usd,
        transacted_at::timestamp_ntz    as transacted_at,
        date_trunc('day', transacted_at)::date as transacted_date,

        case when status = 'completed' then true else false end as is_completed,

        _fivetran_synced::timestamp_ntz as _synced_at

    from source
    where transaction_id is not null
      and status != 'failed'   -- exclude noise; failed txns modeled separately for fraud domain
)

select * from renamed
