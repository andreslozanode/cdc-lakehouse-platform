{# Helper: lee un origen ReplacingMergeTree colapsando versiones con FINAL. #}
{% macro dedup_final(source_relation) -%}
    select * from {{ source_relation }} final
{%- endmacro %}
