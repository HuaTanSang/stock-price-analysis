{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_ticker_symbols_by_industry') }} 
), 

casting_type as (
    select
        cast(symbol as String) as symbol,
        cast(organ_name as String) as organ_name,
        cast(com_type_code as String) as com_type_code, 
        cast(icb_level as String) as icb_level, 
        cast(icb_code as String) as icb_code, 
        cast(icb_name as String) as icb_name 
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by date, symbol
            order by date desc 
        ) as rn
    from casting_type
), 

cleaned as (
    select 
        symbol,
        organ_name,
        com_code_type,
        icb_level,
        icb_code,
        icb_name 
    from deduped
    where rn = 1
)

select * from cleaned
