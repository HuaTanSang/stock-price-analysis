{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}



with source_data as (
    select *
    from {{ ref('raw_vnstock_gold_price') }} 
), 

casting_type as (
    select
        cast(name as String) as name,
        cast(branch as String) as branch,
        
        if(nullIf(buy_price, '-') is null, null, toDecimal64(replace(buy_price, ',', ''), 4)) as buy_price,
        if(nullIf(sell_price, '-') is null, null, toDecimal64(replace(sell_price, ',', ''), 4)) as sell_price, 
        
        toDate(date) as date
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by date, branch, name
            order by date desc 
        ) as rn
    from casting_type
), 

cleaned_data as (
    select 
        name,
        branch,
        buy_price,
        sell_price,
        date
    from deduped
    where rn = 1
)

select * from cleaned_data

