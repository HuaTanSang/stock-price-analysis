{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/vn_ticker_symbol/vn_ticker_symbol.parquet',
        table_structure='symbol String, organ_name String'
    ) }}
)

select * from source_data