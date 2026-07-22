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
        cast(index_symbol as String) as index_symbol,
        if(nullIf(open, '-') is null, null, toDecimal64(replace(open, ',', ''), 4)) as open,
        if(nullIf(high, '-') is null, null, toDecimal64(replace(high, ',', ''), 4)) as high,
        if(nullIf(low, '-') is null, null, toDecimal64(replace(low, ',', ''), 4)) as low,
        if(nullIf(close, '-') is null, null, toDecimal64(replace(close, ',', ''), 4)) as close,
        if(nullIf(volume, '-') is null, null, toUInt64(replace(volume, ',', ''))) as volume,
        toDate(time) as date
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by date, index_symbol
            order by date desc 
        ) as rn
    from casting_type
), 

cleaned_data as (
    select 
        index_symbol,
        open,
        high,
        low,
        close,
        volume,
        date 
    from deduped
    where rn = 1
)

select * from cleaned_data
