{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_stock_price') }} 
), 

casting_type as (
    select
        cast(ticker as String) as _ticker,
        if(nullIf(open, '-') is null, null, toDecimal64(replace(open, ',', ''), 4)) as open,
        if(nullIf(high, '-') is null, null, toDecimal64(replace(high, ',', ''), 4)) as high,
        if(nullIf(low, '-') is null, null, toDecimal64(replace(low, ',', ''), 4)) as low,
        if(nullIf(close, '-') is null, null, toDecimal64(replace(close, ',', ''), 4)) as close,
        if(nullIf(volume, '-') is null, null, toUInt64(replace(volume, ',', ''))) as volume,
        cast(interval as String) as interval,
        toDate(time) as date
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by date, ticker, interval
            order by date desc 
        ) as rn
    from castingtype
), 

cleaned_data as (
    select 
        ticker,
        open,
        high,
        low,
        close,
        volume,
        interval,
        date 
    from deduped
    where rn = 1
)

select * from cleaned_data