{{ 
    config(
        materialized='view'
    ) 
}}

with source_data as (
    select *
    from {{ source('raw', 'raw_vnstock_stock_price') }} 
), 

casting_type as (
    select
        cast(ticker as String) as _ticker,
        if(nullIf(open, '-') is null, null, toDecimal64(replace(open, ',', ''), 4)) as _open,
        if(nullIf(close, '-') is null, null, toDecimal64(replace(close, ',', ''), 4)) as _close,
        if(nullIf(high, '-') is null, null, toDecimal64(replace(high, ',', ''), 4)) as _high,
        if(nullIf(low, '-') is null, null, toDecimal64(replace(low, ',', ''), 4)) as _low,
        if(nullIf(close, '-') is null, null, toDecimal64(replace(close, ',', ''), 4)) as _close, 
        if(nullIf(volume, '-') is null, null, toDecimal64(replace(volume, ',', ''), 4)) as _volume,
        cast(interval as String) as _interval,
        toDate(time) as _date
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by _date, _ticker 
            order by _date desc 
        ) as rn
    from casting_type
), 

cleaned_data as (
    select 
        _ticker,
        _open,
        _high,
        _low,
        _close,
        _volume,
        _interval

    from deduped
    where rn = 1
)

select * from cleaned_data