{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_date'],
        schema='marts'
    ) 
}}

with latest_prices as (
    select
        sp._ticker,
        sp._date,
        sp._close,
        sp._volume,
        lag(sp._close, 1) over (partition by sp._ticker order by sp._date) as prev_close
    from {{ ref('stg_vnstock_stock_price') }} sp
    where sp._interval = '1D'
),

calc_performance as (
    select
        lp._ticker,
        lp._date,
        lp._close,
        lp._volume,
        (_close - prev_close) / nullIf(prev_close, 0) * 100 as daily_return_pct,
        ts._organ_name,
        ts._industry_name,
        ts._en_industry_name,
        ts._sector,
        ts._en_sector,
        ts._exchange
    from latest_prices lp
    left join {{ ref('stg_vnstock_ticker_symbols') }} ts
        on lp._ticker = ts._ticker
    where prev_close is not null
)

select
    _date,
    _ticker,
    _organ_name,
    _industry_name,
    _en_industry_name,
    _sector,
    _en_sector,
    _exchange,
    _close,
    _volume,
    round(daily_return_pct, 2) as daily_return_pct,
    abs(round(daily_return_pct, 2)) as change_magnitude_size,
    -- Turnover proxy for treemap sizing (close * volume)
    round(cast(_close as Float64) * cast(_volume as Float64), 0) as turnover_proxy
from calc_performance
where daily_return_pct is not null
