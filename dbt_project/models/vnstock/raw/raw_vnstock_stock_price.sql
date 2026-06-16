{{ 
    config(
        materialized='view',
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/stock_price_interval=1D/*/*/*/*.parquet',
        table_structure='ticker String, time String, open String, high String, low String, close String, volume String, interval String'
    ) }}
)

select * from source_data