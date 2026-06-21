{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/vn_ticker_symbol/vn_ticker_symbol.parquet',
        table_structure='ticker String, organ_name String, organ_short_name String, en_organ_name String, en_organ_short_name String, industry_name String, en_industry_name String, supersector String, en_supersector String, sector String, en_sector String, subsector String, en_subsector String, listed_date String, delisted_date String, exchange String'
    ) }}
)

select * from source_data
