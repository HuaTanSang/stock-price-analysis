{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/market_index/index=*/*/*/*/*.parquet',
        table_structure='time String, open String, high String, low String, close String, volume String, index_symbol String'
    ) }}
)

select * from source_data
