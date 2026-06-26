-- Une orders + items + cliente para construir hechos a nivel pedido.
with orders as (select * from {{ ref('stg_orders') }}),
items as (
    select
        order_id,
        count(*)              as item_count,
        sum(quantity)         as total_units,
        sum(line_amount)      as items_amount
    from {{ ref('stg_order_items') }}
    group by order_id
),
customers as (select customer_id, country, segment from {{ ref('stg_customers') }})
select
    o.order_id,
    o.customer_id,
    c.country,
    c.segment,
    o.status,
    o.currency,
    o.total_amount,
    coalesce(i.item_count, 0)  as item_count,
    coalesce(i.total_units, 0) as total_units,
    coalesce(i.items_amount, 0) as items_amount,
    o.order_date,
    o.updated_at
from orders o
left join items i on o.order_id = i.order_id
left join customers c on o.customer_id = c.customer_id
