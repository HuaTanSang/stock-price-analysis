{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/fundamentals/ticker=*/report=cash_flow/*/*/*/*.parquet',
        table_structure='ticker String, year String, quarter String, invest_cost String, from_invest String, from_financial String, from_sale String, free_cash_flow String'
    ) }}
)

select * from source_data
