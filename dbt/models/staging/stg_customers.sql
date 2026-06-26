-- Estado actual deduplicado del ReplacingMergeTree (FINAL colapsa versiones).
with src as (
    select
        customer_id,
        lower(email)      as email,
        full_name,
        country,
        segment,
        updated_at
    from {{ source('serving', 'customers_rt') }} final
)
select * from src
