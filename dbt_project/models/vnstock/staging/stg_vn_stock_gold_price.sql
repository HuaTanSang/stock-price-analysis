{{ 
    config(
        materialized='view'
    ) 
}}

with source_data as (
    select *
    from {{ source('raw', 'raw_vnstock_gold_price') }} 
), 

casting_type as (
    select
        cast(name as String) as _name,
        cast(branch as String) as _branch,
        
        if(nullIf(buy_price, '-') is null, null, toDecimal64(replace(buy_price, ',', ''), 4)) as _buy_price,
        if(nullIf(sell_price, '-') is null, null, toDecimal64(replace(sell_price, ',', ''), 4)) as _sell_price, 
        
        toDate(date) as _date
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by _date, _branch 
            order by _date desc 
        ) as rn
    from casting_type
), 

cleaned_data as (
    select 
        _name,
        _branch,
        _buy_price,
        _sell_price,
        _date
    from deduped
    where rn = 1
)

select * from cleaned_data

