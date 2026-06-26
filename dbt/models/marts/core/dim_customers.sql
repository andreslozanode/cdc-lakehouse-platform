{{ config(materialized='table', engine='MergeTree()', order_by='customer_id') }}

with c as (select * from {{ ref('stg_customers') }}),
agg as (
    select
        customer_id,
        count(distinct order_id) as lifetime_orders,
        sum(total_amount)        as lifetime_value,
        max(order_date)          as last_order_date
    from {{ ref('stg_orders') }}
    group by customer_id
),
region as (select * from {{ ref('country_region') }})
select
    c.customer_id,
    c.email,
    c.full_name,
    c.country,
    r.region,
    c.segment,
    coalesce(a.lifetime_orders, 0) as lifetime_orders,
    coalesce(a.lifetime_value, 0)  as lifetime_value,
    a.last_order_date,
    c.updated_at
from c
left join agg a on c.customer_id = a.customer_id
left join region r on c.country = r.country
