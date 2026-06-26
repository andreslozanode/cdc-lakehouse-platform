with src as (
    select
        order_id,
        customer_id,
        status,
        currency,
        total_amount,
        updated_at,
        toDate(updated_at) as order_date
    from {{ source('serving', 'orders_rt') }} final
)
select * from src
