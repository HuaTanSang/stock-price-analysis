{{ 
    config(
        materialized='view',
    ) 
}}

with source_data as (
    select  
        extract(_file, '\\d{4}-\\d{2}-\\d{2}') AS time,
        currency,
        buy_cash,
        buy_transfer,
        sell
    from {{ s3_source(
        s3_path='vn-stock/exchange_rate/*/*/*/*.parquet',
        table_structure='currency String, buy_cash String, buy_transfer String, sell String'
    ) }}
)

select * from source_data