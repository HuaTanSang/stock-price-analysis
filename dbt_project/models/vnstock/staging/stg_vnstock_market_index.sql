{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_market_index') }} 
), 

casting_type as (
    select
        cast(index_symbol as String) as _index_symbol,
        if(nullIf(open, '-') is null, null, toDecimal64(replace(open, ',', ''), 4)) as _open,
        if(nullIf(high, '-') is null, null, toDecimal64(replace(high, ',', ''), 4)) as _high,
        if(nullIf(low, '-') is null, null, toDecimal64(replace(low, ',', ''), 4)) as _low,
        if(nullIf(close, '-') is null, null, toDecimal64(replace(close, ',', ''), 4)) as _close,
        if(nullIf(volume, '-') is null, null, toUInt64(replace(volume, ',', ''))) as _volume,
        toDate(time) as _date
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by _date, _index_symbol
            order by _date desc 
        ) as rn
    from casting_type
), 

cleaned_data as (
    select 
        _index_symbol,
        _open,
        _high,
        _low,
        _close,
        _volume,
        _date 
    from deduped
    where rn = 1
)

select * from cleaned_data
