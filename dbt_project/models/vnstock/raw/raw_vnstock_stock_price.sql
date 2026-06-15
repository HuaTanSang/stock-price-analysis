{{ 
    config(
        materialized='view',
    ) 
}}

with source_data as (
    select  
        ticker,
        time,
        open,
        high,
        low,
        close,
        volume,
        interval 
    from {{ s3_source(
        s3_path='vn-stock/stock_price_interval=1D/*/*/*/*.parquet',
        table_structure='ticker String, time String, open String, high String, low String, close String, volume String, interval String'
    ) }}
)

select * from source_data