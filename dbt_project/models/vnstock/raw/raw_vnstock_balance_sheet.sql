{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/fundamentals/ticker=*/report=balance_sheet/*/*/*/*.parquet',
        table_structure='ticker String, year String, quarter String, short_asset String, cash String, short_invest String, short_receivable String, inventory String, long_asset String, fixed_asset String, asset String, debt String, short_debt String, long_debt String, equity String, capital String, un_distributed_income String, minor_share_holder_profit String, payable String'
    ) }}
)

select * from source_data
