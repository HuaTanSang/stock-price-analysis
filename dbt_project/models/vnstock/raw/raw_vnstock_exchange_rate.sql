{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/exchange_rate/*/*/*/*.parquet',
        table_structure='currency_code String, currency_name String, buy_cash String, buy_transfer String, sell String, date String'
    ) }}
)

select * from source_data