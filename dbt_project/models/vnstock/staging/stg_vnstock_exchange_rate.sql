{{ 
    config(
        materialized='view'
    ) 
}}

with source_data as (
    select *
    from {{ source('raw', 'raw_vnstock_exchange_rate') }} 
), 

casting_type as (
    select
        cast(currency_code as String) as _currency_code,
        cast(currency_name as String) as _currency_name,
        
        if(nullIf(buy_cash, '-') is null, null, toDecimal64(replace(buy_cash, ',', ''), 4)) as _buy_cash,
        if(nullIf(buy_transfer, '-') is null, null, toDecimal64(replace(buy_transfer, ',', ''), 4)) as _buy_transfer,
        if(nullIf(sell, '-') is null, null, toDecimal64(replace(sell, ',', ''), 4)) as _sell, 
        
        toDate(date) as _date
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by _date, _currency_code 
            order by _date desc 
        ) as rn
    from casting_type
), 

cleaned_data as (
    select 
        _currency_code,
        _currency_name,
        _buy_cash,
        _buy_transfer,
        _sell,
        _date
    from deduped
    where rn = 1
)

select * from cleaned_data

