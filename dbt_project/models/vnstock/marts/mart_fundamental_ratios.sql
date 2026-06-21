{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_ticker', '_year', '_quarter'],
        schema='marts'
    ) 
}}

with income as (
    select * from {{ ref('stg_vnstock_income_statement') }}
),

balance as (
    select * from {{ ref('stg_vnstock_balance_sheet') }}
),

cashflow as (
    select * from {{ ref('stg_vnstock_cash_flow') }}
),

ticker_ref as (
    select * from {{ ref('stg_vnstock_ticker_symbols') }}
),

-- Get the latest close price for each ticker per quarter-end (approximate)
latest_price as (
    select
        _ticker,
        toYear(_date) as _year,
        toQuarter(_date) as _quarter,
        argMax(_close, _date) as quarter_end_close
    from {{ ref('stg_vnstock_stock_price') }}
    group by _ticker, toYear(_date), toQuarter(_date)
),

combined as (
    select
        i._ticker as _ticker,
        i._year as _year,
        i._quarter as _quarter,
        tr._organ_name,
        tr._industry_name,
        tr._en_industry_name,
        tr._sector,
        tr._en_sector,
        tr._exchange,

        -- Income Statement metrics
        i._revenue,
        i._gross_profit,
        i._operation_profit,
        i._post_tax_profit,
        i._share_holder_income,
        i._ebitda,
        i._year_revenue_growth,
        i._quarter_revenue_growth,

        -- Balance Sheet metrics
        b._asset,
        b._equity,
        b._debt,
        b._short_debt,
        b._long_debt,
        b._cash,
        b._inventory,
        b._capital,

        -- Cash Flow metrics
        cf._from_sale,
        cf._from_invest,
        cf._from_financial,
        cf._free_cash_flow,

        -- Price for P/E calculation
        lp.quarter_end_close

    from income i
    left join balance b
        on i._ticker = b._ticker 
        and i._year = b._year 
        and i._quarter = b._quarter
    left join cashflow cf
        on i._ticker = cf._ticker 
        and i._year = cf._year 
        and i._quarter = cf._quarter
    left join ticker_ref tr
        on i._ticker = tr._ticker
    left join latest_price lp
        on i._ticker = lp._ticker
        and i._year = lp._year
        and i._quarter = lp._quarter
)

select
    _ticker,
    coalesce(_year, 0) as _year,
    coalesce(_quarter, 0) as _quarter,
    _organ_name,
    _industry_name,
    _en_industry_name,
    _sector,
    _en_sector,
    _exchange,

    -- Revenue & Profitability
    _revenue,
    _gross_profit,
    _operation_profit,
    _post_tax_profit,
    _share_holder_income,
    _ebitda,

    -- Gross margin
    round(
        cast(_gross_profit as Nullable(Float64)) / nullIf(cast(_revenue as Nullable(Float64)), 0) * 100, 2
    ) as gross_margin_pct,

    -- Operating margin
    round(
        cast(_operation_profit as Nullable(Float64)) / nullIf(cast(_revenue as Nullable(Float64)), 0) * 100, 2
    ) as operating_margin_pct,

    -- Net profit margin
    round(
        cast(_post_tax_profit as Nullable(Float64)) / nullIf(cast(_revenue as Nullable(Float64)), 0) * 100, 2
    ) as net_profit_margin_pct,

    -- ROE = Net Income / Equity
    round(
        cast(_post_tax_profit as Nullable(Float64)) / nullIf(cast(_equity as Nullable(Float64)), 0) * 100, 2
    ) as roe_pct,

    -- ROA = Net Income / Total Assets
    round(
        cast(_post_tax_profit as Nullable(Float64)) / nullIf(cast(_asset as Nullable(Float64)), 0) * 100, 2
    ) as roa_pct,

    -- Debt-to-Equity
    round(
        cast(_debt as Nullable(Float64)) / nullIf(cast(_equity as Nullable(Float64)), 0), 2
    ) as debt_to_equity,

    -- Current Ratio approximation (short_asset / short_debt)
    -- Note: using what's available — short_asset isn't in this query but could be added
    
    -- EPS = Shareholder Income / Capital (proxy for outstanding shares)
    if(_capital > 0,
       round(cast(_share_holder_income as Nullable(Float64)) / (cast(_capital as Nullable(Float64)) / 10000), 0),
       null
    ) as eps_approx,

    -- P/E = Price / EPS
    if(_capital > 0 and _share_holder_income > 0,
       round(
           cast(quarter_end_close as Nullable(Float64)) 
           / (cast(_share_holder_income as Nullable(Float64)) / (cast(_capital as Nullable(Float64)) / 10000)),
           2
       ),
       null
    ) as pe_ratio_approx,

    -- Growth rates
    round(cast(_year_revenue_growth as Nullable(Float64)) * 100, 2) as year_revenue_growth_pct,
    round(cast(_quarter_revenue_growth as Nullable(Float64)) * 100, 2) as quarter_revenue_growth_pct,

    -- Balance Sheet
    _asset,
    _equity,
    _debt,
    _cash,
    _inventory,

    -- Cash Flow
    _from_sale as operating_cash_flow,
    _from_invest as investing_cash_flow,
    _from_financial as financing_cash_flow,
    _free_cash_flow,

    quarter_end_close

from combined
