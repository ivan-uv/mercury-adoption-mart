-- models/staging/stg_accounts.sql
-- Standardizes raw account data from source (e.g. Fivetran → Snowflake).
-- One row per Mercury business account.

with source as (
    select * from {{ source('mercury_raw', 'accounts') }}
),

renamed as (
    select
        -- keys
        account_id,
        business_id,

        -- account metadata
        lower(trim(account_type))                       as account_type,      -- 'checking', 'savings'
        lower(trim(partner_bank))                       as partner_bank,      -- 'choice_financial', 'column_na'
        lower(trim(industry_segment))                   as industry_segment,  -- 'saas', 'ecommerce', 'agency', 'other'
        lower(trim(account_status))                     as account_status,    -- 'active', 'suspended', 'closed'

        -- timestamps
        opened_at::timestamp_ntz                        as opened_at,
        closed_at::timestamp_ntz                        as closed_at,
        first_deposit_at::timestamp_ntz                 as first_deposit_at,

        -- computed
        datediff('day', opened_at, coalesce(first_deposit_at, current_timestamp)) as days_to_first_deposit,
        case when account_status = 'active' then true else false end             as is_active,

        -- audit
        _fivetran_synced::timestamp_ntz                 as _synced_at

    from source
    where account_id is not null
)

select * from renamed
