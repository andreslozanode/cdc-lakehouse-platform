{% snapshot customers_snapshot %}
{{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='timestamp',
      updated_at='updated_at',
      invalidate_hard_deletes=True
    )
}}
-- SCD Type 2 sobre el estado actual: historiza cambios de segment/country/email.
select customer_id, email, full_name, country, segment, updated_at
from {{ source('serving', 'customers_rt') }} final
{% endsnapshot %}
