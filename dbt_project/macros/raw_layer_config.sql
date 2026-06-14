{% macro raw_layer_config() -%}
{{
    config (
        materialized='view',
        tags=['bronze', 'raw' ,'minio', 'vnstock'] 
    )
}}
{%- endmacro %}
