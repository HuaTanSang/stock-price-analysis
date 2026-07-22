{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_ticker_symbols_by_exchange') }} 
), 

casting_type as (
    select
        cast(symbol as String) as symbol,
        cast(organ_name as String) as organ_name,
        cast(en_organ_name as String) as en_organ_name, 
        cast(exchange as ) as exchange_name, 
        
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
        en_organ_name,
        exchange_name
    from deduped
    where rn = 1
)

select * from cleaned
