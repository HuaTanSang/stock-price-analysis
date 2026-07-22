{{ 
    config(
        materialized='view',
        schema='raw'
    ) 
}}

with source_data as (
    select *
    from {{ s3_source(
        s3_path='vn-stock/vn_ticker_symbol_by_industry/vn_ticker_symbol_by_industry.parquet',
        table_structure='symbol String, organ_name String, com_type_code String, icb_level String, icb_code String, icb_name String'
    ) }}
)

select * from source_data