{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['date', 'ticker'],
        schema='marts'
    ) 
}}

with latest_prices as (
    select
        sp.ticker,
        sp.date,
        sp.close,
        sp.volume,

        lagInFrame(sp.close, 1, sp.close) over wticker as prev_close,
        row_number() over w_ticker as row_num
    from {{ ref('stg_vnstock_stock_price') }} sp
    where sp.interval = '1D'
    window 
        w_ticker as (partition by sp.ticker order by sp.date)
),

calc_performance as (
    select
        lp.ticker,
        lp.date,
        lp._close,
        lp._volume,
        -- Nhân 1.0 để tránh lỗi chia số nguyên (Integer Division)
        ((lp._close * 1.0 - lp.prev_close) / nullIf(lp.prev_close, 0)) * 100.0 as daily_return_pct,
        ts.organ_name,
        ts.industry_name,
        ts.en_industry_name,
        ts.sector,
        ts.en_sector,
        ts.exchange
    from latest_prices lp
    left join {{ ref('stg_vnstock_ticker_symbols') }} ts
        on lp.ticker = ts.ticker
    where lp.row_num > 1 
)

select
    date,
    ticker,
    organ_name,
    industry_name,
    en_industry_name,
    sector,
    en_sector,
    exchange,
    close,
    volume,
    round(daily_return_pct, 2) as daily_return_pct,
    abs(round(daily_return_pct, 2)) as change_magnitude_size,
    -- Turnover proxy for treemap sizing (close * volume)
    round(cast(_close as Float64) * cast(_volume as Float64), 0) as turnover_proxy
from calc_performance