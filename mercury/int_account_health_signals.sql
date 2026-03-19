-- models/intermediate/int_account_health_signals.sql
-- Rolls up product activity to the account level.
-- Produces features suitable for propensity model consumption and
-- exec-level activation dashboards.
-- Ephemeral: joins into the mart directly.

with accounts as (
    select * from {{ ref('stg_accounts') }}
),

product_activity as (
    select * from {{ ref('int_account_product_activity') }}
),

-- Pivot activity to account level
account_product_summary as (
    select
        account_id,
        count(distinct product_slug)                                        as products_enrolled,
        count(distinct case when is_active_30d then product_slug end)       as products_active_30d,
        count(distinct case when is_dormant then product_slug end)          as products_dormant,

        -- revenue-bearing products (proxy for monetization depth)
        count(distinct case
            when product_slug in ('credit_card', 'treasury', 'working_capital_loan', 'venture_debt')
            then product_slug
        end)                                                                as revenue_products_enrolled,

        -- cross-sell surface: enrolled in core but not yet in premium
        max(case when product_slug = 'checking' then 1 else 0 end)         as has_checking,
        max(case when product_slug = 'credit_card' then 1 else 0 end)      as has_credit_card,
        max(case when product_slug = 'treasury' then 1 else 0 end)         as has_treasury,
        max(case when product_slug = 'working_capital_loan' then 1 else 0 end) as has_loan,
        max(case when product_slug = 'bill_pay' then 1 else 0 end)         as has_bill_pay,
        max(case when product_slug = 'invoicing' then 1 else 0 end)        as has_invoicing,

        -- engagement depth
        sum(total_volume_usd)                                               as lifetime_volume_usd,
        sum(volume_last_30d_usd)                                            as volume_last_30d_usd,
        avg(days_enrollment_to_first_use)                                   as avg_days_to_first_use,

        min(first_transaction_at)                                           as first_ever_transaction_at

    from product_activity
    group by 1
),

-- Compute derived health score and cross-sell signals
final as (
    select
        a.account_id,
        a.business_id,
        a.industry_segment,
        a.opened_at,
        a.days_to_first_deposit,
        a.is_active,

        s.products_enrolled,
        s.products_active_30d,
        s.products_dormant,
        s.revenue_products_enrolled,
        s.has_checking,
        s.has_credit_card,
        s.has_treasury,
        s.has_loan,
        s.has_bill_pay,
        s.has_invoicing,
        s.lifetime_volume_usd,
        s.volume_last_30d_usd,
        s.avg_days_to_first_use,
        s.first_ever_transaction_at,

        -- Multi-product score (0–6 range; useful as propensity feature)
        (s.has_checking + s.has_credit_card + s.has_treasury +
         s.has_loan + s.has_bill_pay + s.has_invoicing)                     as product_breadth_score,

        -- Candidate for next cross-sell (mirrors Square AMs' prioritization logic)
        case
            when s.has_checking = 1 and s.has_credit_card = 0 then 'credit_card'
            when s.has_credit_card = 1 and s.has_treasury = 0
                 and s.volume_last_30d_usd > 10000             then 'treasury'
            when s.has_checking = 1 and s.has_loan = 0
                 and s.lifetime_volume_usd > 50000             then 'working_capital_loan'
            when s.has_checking = 1 and s.has_bill_pay = 0    then 'bill_pay'
            else null
        end                                                                 as recommended_next_product

    from accounts a
    left join account_product_summary s using (account_id)
)

select * from final
