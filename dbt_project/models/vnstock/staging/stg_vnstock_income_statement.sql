{{ 
    config(
        materialized='view',
        schema='staging'
    ) 
}}


with source_data as (
    select *
    from {{ ref('raw_vnstock_income_statement') }} 
), 

casting_type as (
    select
        cast(ticker as String) as ticker,
        toUInt16OrNull(year) as year,
        toUInt8OrNull(quarter) as quarter,
        
        if(nullIf(revenue, '') is null, null, toDecimal128(replace(revenue, ',', ''), 0)) as revenue,
        if(nullIf(year_revenue_growth, '') is null, null, toDecimal64(replace(year_revenue_growth, ',', ''), 6)) as year_revenue_growth,
        if(nullIf(quarter_revenue_growth, '') is null, null, toDecimal64(replace(quarter_revenue_growth, ',', ''), 6)) as quarter_revenue_growth,
        if(nullIf(cost_of_good_sold, '') is null, null, toDecimal128(replace(cost_of_good_sold, ',', ''), 0)) as cost_of_good_sold,
        if(nullIf(gross_profit, '') is null, null, toDecimal128(replace(gross_profit, ',', ''), 0)) as gross_profit,
        if(nullIf(operation_expense, '') is null, null, toDecimal128(replace(operation_expense, ',', ''), 0)) as operation_expense,
        if(nullIf(operation_profit, '') is null, null, toDecimal128(replace(operation_profit, ',', ''), 0)) as operation_profit,
        if(nullIf(year_operation_profit_growth, '') is null, null, toDecimal64(replace(year_operation_profit_growth, ',', ''), 6)) as year_operation_profit_growth,
        if(nullIf(quarter_operation_profit_growth, '') is null, null, toDecimal64(replace(quarter_operation_profit_growth, ',', ''), 6)) as quarter_operation_profit_growth,
        if(nullIf(interest_expense, '') is null, null, toDecimal128(replace(interest_expense, ',', ''), 0)) as interest_expense,
        if(nullIf(pre_tax_profit, '') is null, null, toDecimal128(replace(pre_tax_profit, ',', ''), 0)) as pre_tax_profit,
        if(nullIf(post_tax_profit, '') is null, null, toDecimal128(replace(post_tax_profit, ',', ''), 0)) as post_tax_profit,
        if(nullIf(share_holder_income, '') is null, null, toDecimal128(replace(share_holder_income, ',', ''), 0)) as share_holder_income,
        if(nullIf(year_share_holder_income_growth, '') is null, null, toDecimal64(replace(year_share_holder_income_growth, ',', ''), 6)) as year_share_holder_income_growth,
        if(nullIf(quarter_share_holder_income_growth, '') is null, null, toDecimal64(replace(quarter_share_holder_income_growth, ',', ''), 6)) as quarter_share_holder_income_growth,
        if(nullIf(ebitda, '') is null, null, toDecimal128(replace(ebitda, ',', ''), 0)) as ebitda
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
