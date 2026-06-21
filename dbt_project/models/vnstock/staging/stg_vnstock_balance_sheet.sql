{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_balance_sheet') }} 
), 

casting_type as (
    select
        cast(ticker as String) as _ticker,
        toUInt16OrNull(year) as _year,
        toUInt8OrNull(quarter) as _quarter,
        
        if(nullIf(short_asset, '') is null, null, toDecimal128(replace(short_asset, ',', ''), 0)) as _short_asset,
        if(nullIf(cash, '') is null, null, toDecimal128(replace(cash, ',', ''), 0)) as _cash,
        if(nullIf(short_invest, '') is null, null, toDecimal128(replace(short_invest, ',', ''), 0)) as _short_invest,
        if(nullIf(short_receivable, '') is null, null, toDecimal128(replace(short_receivable, ',', ''), 0)) as _short_receivable,
        if(nullIf(inventory, '') is null, null, toDecimal128(replace(inventory, ',', ''), 0)) as _inventory,
        if(nullIf(long_asset, '') is null, null, toDecimal128(replace(long_asset, ',', ''), 0)) as _long_asset,
        if(nullIf(fixed_asset, '') is null, null, toDecimal128(replace(fixed_asset, ',', ''), 0)) as _fixed_asset,
        if(nullIf(asset, '') is null, null, toDecimal128(replace(asset, ',', ''), 0)) as _asset,
        if(nullIf(debt, '') is null, null, toDecimal128(replace(debt, ',', ''), 0)) as _debt,
        if(nullIf(short_debt, '') is null, null, toDecimal128(replace(short_debt, ',', ''), 0)) as _short_debt,
        if(nullIf(long_debt, '') is null, null, toDecimal128(replace(long_debt, ',', ''), 0)) as _long_debt,
        if(nullIf(equity, '') is null, null, toDecimal128(replace(equity, ',', ''), 0)) as _equity,
        if(nullIf(capital, '') is null, null, toDecimal128(replace(capital, ',', ''), 0)) as _capital,
        if(nullIf(un_distributed_income, '') is null, null, toDecimal128(replace(un_distributed_income, ',', ''), 0)) as _un_distributed_income,
        if(nullIf(minor_share_holder_profit, '') is null, null, toDecimal128(replace(minor_share_holder_profit, ',', ''), 0)) as _minor_share_holder_profit,
        if(nullIf(payable, '') is null, null, toDecimal128(replace(payable, ',', ''), 0)) as _payable
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
