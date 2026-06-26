{{ config(
    materialized='incremental',
    engine='MergeTree()',
    order_by='(order_date, customer_id, order_id)',
    partition_by='toYYYYMM(order_date)',
    unique_key='order_id',
    incremental_strategy='delete+insert'
) }}

select
    order_id,
    customer_id,
    country,
    segment,
    status,
    currency,
    total_amount,
    item_count,
    total_units,
    items_amount,
    order_date,
    updated_at
from {{ ref('int_order_enriched') }}

{% if is_incremental() %}
  where order_date >= today() - {{ var('hot_lookback_days') }}
{% endif %}
