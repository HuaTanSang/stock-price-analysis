{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}


with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/gold_price/*/*/*/*.parquet',
        table_structure='name String, branch String, buy_price String, sell_price String, date String'
    ) }}
)

select * from source_data