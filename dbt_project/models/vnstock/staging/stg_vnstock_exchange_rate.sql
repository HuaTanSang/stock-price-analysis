{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_exchange_rate') }}
), 

casting_type as (
    select
        cast(currency_code as String) as currency_code,
        cast(currency_name as String) as currency_name,
        
        if(nullIf(buy_cash, '-') is null, null, toDecimal64(replace(buy_cash, ',', ''), 4)) as buy_cash,
        if(nullIf(buy_transfer, '-') is null, null, toDecimal64(replace(buy_transfer, ',', ''), 4)) as buy_transfer,
        if(nullIf(sell, '-') is null, null, toDecimal64(replace(sell, ',', ''), 4)) as sell, 
        
        toDate(date) as date
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by date, currency_code 
            order by date desc 
        ) as rn
    from casting_type
), 

cleaned_data as (
    select 
        currency_code,
        currency_name,
        buy_cash,
        buy_transfer,
        sell,
        date
    from deduped
    where rn = 1
)

select * from cleaned_data

