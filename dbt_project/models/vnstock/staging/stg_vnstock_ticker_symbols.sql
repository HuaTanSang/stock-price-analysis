{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_ticker_symbols') }} 
), 

cleaned as (
    select
        cast(ticker as String) as _ticker,
        cast(organ_name as String) as _organ_name,
        cast(organ_short_name as String) as _organ_short_name,
        cast(en_organ_name as String) as _en_organ_name,
        cast(industry_name as String) as _industry_name,
        cast(en_industry_name as String) as _en_industry_name,
        cast(supersector as String) as _supersector,
        cast(en_supersector as String) as _en_supersector,
        cast(sector as String) as _sector,
        cast(en_sector as String) as _en_sector,
        cast(subsector as String) as _subsector,
        cast(en_subsector as String) as _en_subsector,
        if(listed_date = '' or listed_date is null, null, toDate(listed_date)) as _listed_date,
        if(delisted_date = '' or delisted_date is null, null, toDate(delisted_date)) as _delisted_date,
        cast(exchange as String) as _exchange
    from 
        source_data    
)

select * from cleaned
