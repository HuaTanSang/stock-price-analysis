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
        cast(ticker as String) as _ticker,
        toUInt16OrNull(year) as _year,
        toUInt8OrNull(quarter) as _quarter,
        
        if(nullIf(invest_cost, '') is null, null, toDecimal128(replace(invest_cost, ',', ''), 0)) as _invest_cost,
        if(nullIf(from_invest, '') is null, null, toDecimal128(replace(from_invest, ',', ''), 0)) as _from_invest,
        if(nullIf(from_financial, '') is null, null, toDecimal128(replace(from_financial, ',', ''), 0)) as _from_financial,
        if(nullIf(from_sale, '') is null, null, toDecimal128(replace(from_sale, ',', ''), 0)) as _from_sale,
        if(nullIf(free_cash_flow, '') is null, null, toDecimal128(replace(free_cash_flow, ',', ''), 0)) as _free_cash_flow
    from 
        source_data    
),

deduped as (
    select 
        *,
        row_number() over (
            partition by _ticker, _year, _quarter
            order by _year desc, _quarter desc 
        ) as rn
    from casting_type
)

select * except(rn)
from deduped
where rn = 1
