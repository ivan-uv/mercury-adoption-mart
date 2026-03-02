-- models/staging/stg_product_enrollments.sql
-- One row per account × product enrollment event.
-- Products: checking, savings, credit_card, treasury, working_capital_loan,
--           venture_debt, bill_pay, invoicing, expense_management

with source as (
    select * from {{ source('mercury_raw', 'product_enrollments') }}
),

renamed as (
    select
        enrollment_id,
        account_id,
        lower(trim(product_slug))       as product_slug,
        lower(trim(enrollment_status))  as enrollment_status,  -- 'active', 'cancelled', 'pending'

        enrolled_at::timestamp_ntz      as enrolled_at,
        cancelled_at::timestamp_ntz     as cancelled_at,

        case
            when enrollment_status = 'active' then true
            else false
        end                             as is_currently_enrolled,

        _fivetran_synced::timestamp_ntz as _synced_at

    from source
    where account_id is not null
      and product_slug is not null
)

select * from renamed
