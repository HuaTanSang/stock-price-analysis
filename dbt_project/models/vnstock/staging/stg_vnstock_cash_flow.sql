{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_cash_flow') }} 
), 

casting_type as (
    select
        cast(ticker as String) as ticker,
        toUInt16OrNull(year) as year,
        toUInt8OrNull(quarter) as quarter,
        
        if(nullIf(invest_cost, '') is null, null, toDecimal128(replace(invest_cost, ',', ''), 0)) as invest_cost,
        if(nullIf(from_invest, '') is null, null, toDecimal128(replace(from_invest, ',', ''), 0)) as from_invest,
        if(nullIf(from_financial, '') is null, null, toDecimal128(replace(from_financial, ',', ''), 0)) as from_financial,
        if(nullIf(from_sale, '') is null, null, toDecimal128(replace(from_sale, ',', ''), 0)) as from_sale,
        if(nullIf(free_cash_flow, '') is null, null, toDecimal128(replace(free_cash_flow, ',', ''), 0)) as free_cash_flow
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by ticker, year, quarter
            order by year desc, quarter desc 
        ) as rn
    from casting_type
)

select * except(rn)
from deduped
where rn = 1
