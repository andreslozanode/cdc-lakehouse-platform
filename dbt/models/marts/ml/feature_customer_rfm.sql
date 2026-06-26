{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='customer_id',
    tags=['ml','feature_store']
) }}

-- Features RFM (Recency, Frequency, Monetary) + segmentación por quintiles.
-- Tabla de features OFFLINE (entrenamiento). El online serving usa ClickHouse
-- directamente sobre fct_orders. Reproducibilidad: Iceberg time-travel en silver.
with base as (
    select
        customer_id,
        max(order_date)            as last_order_date,
        count(distinct order_id)   as frequency,
        sum(total_amount)          as monetary,
        avg(total_amount)          as avg_ticket,
        sum(total_units)           as total_units
    from {{ ref('fct_orders') }}
    where status in ('paid', 'shipped', 'delivered')
    group by customer_id
),
scored as (
    select
        *,
        dateDiff('day', last_order_date, today())               as recency_days,
        ntile(5) over (order by dateDiff('day', last_order_date, today()) desc) as r_score,
        ntile(5) over (order by frequency)                       as f_score,
        ntile(5) over (order by monetary)                        as m_score
    from base
)
select
    customer_id,
    recency_days,
    frequency,
    monetary,
    avg_ticket,
    total_units,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score)              as rfm_total,
    concat(toString(r_score), toString(f_score), toString(m_score)) as rfm_segment,
    now64(3)                                   as feature_ts
from scored
