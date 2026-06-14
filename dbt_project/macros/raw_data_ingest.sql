{% macro raw_data_ingestion(object_key) -%}

    {% set minio_endpoint = env_var('MINIO_ENDPOINT', 'http://localhost:9000') %}
    {% set minio_accesskey = env_var('MINIO_ACCESS_KEY', 'minioadmin') %}
    {% set minio_secret_key = env_var('MINIO_SECRET_KEY', 'minioadmin') %} 
    {% set object_path = minio_endpoint ~ "/" ~ object_key %}

    SELECT * 
    FROM s3 
    (
        '{{ object_path }}', 
        '{{ minio_accesskey }}', 
        '{{ minio_secret_key }}', 
        'Parquet'
    )

{%- endmacro %}