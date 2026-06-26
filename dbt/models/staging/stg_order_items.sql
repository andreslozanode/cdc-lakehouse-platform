with src as (
    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        line_amount
    from {{ source('serving', 'order_items_rt') }} final
)
select * from src
