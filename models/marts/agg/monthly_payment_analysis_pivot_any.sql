-- This model demonstrates the explicit PIVOT option for Fusion compatibility.
-- Payment methods are listed explicitly so Fusion can statically infer
-- the output schema during compilation.

{{ config(
    materialized='view',
    tags=['introspection_error', 'pivot_any', 'monthly_analysis']
) }}

with monthly_payment_data as (
    select 
        date_trunc('month', o.ordered_at) as order_month,
        -- Simulate payment methods based on order patterns
        case 
            when hash(o.order_id) % 3 = 0 then 'credit_card'
            when hash(o.order_id) % 3 = 1 then 'debit_card'
            else 'paypal'
        end as payment_method,
        -- Simulate order totals based on items
        sum(p.product_price * 0.01) as payment_method_revenue,  -- Convert cents to dollars
        count(*) as transaction_count
    from {{ ref('stg_orders') }} o
    join {{ ref('stg_order_items') }} i on o.order_id = i.order_id
    join {{ ref('stg_products') }} p on i.product_id = p.product_id
    where o.ordered_at >= to_timestamp('2023-01-01', 'YYYY-MM-DD')
    group by 
        date_trunc('month', o.ordered_at),
        case 
            when hash(o.order_id) % 3 = 0 then 'credit_card'
            when hash(o.order_id) % 3 = 1 then 'debit_card'
            else 'paypal'
        end
),

-- Fusion-safe explicit pivot values 
monthly_revenue_by_payment_method as (
    select *
    from monthly_payment_data
    PIVOT (
        sum(payment_method_revenue)
        FOR payment_method IN ('credit_card', 'debit_card', 'paypal')
    ) as pivot_table
)

select 
    -- Deterministic pivoted columns from explicit values above
    *
from monthly_revenue_by_payment_method
order by 1