{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/vn_ticker_symbol_by_exchange/vn_ticker_symbol_by_exchange.parquet',
        table_structure='symbol String, organ_name String, en_organ_name String, exchange String, type String, id String'
    ) }}
)

select * from source_data
