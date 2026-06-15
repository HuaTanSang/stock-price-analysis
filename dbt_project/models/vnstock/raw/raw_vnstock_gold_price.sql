{{ 
    config(
        materialized='view',
    ) 
}}

with source_data as (
    select  
        time,
        buy,
        sell,
        type
    from {{ s3_source(
        s3_path='vn-stock/gold_price/*/*/*/*.parquet',
        table_structure='time String, buy String, sell String, type String'
    ) }}
)

select * from source_data