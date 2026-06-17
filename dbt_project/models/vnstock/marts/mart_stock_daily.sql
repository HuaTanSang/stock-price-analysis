{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_date'],
        schema='marts'
    ) 
}}

with base as (
    select
        _ticker,
        _date,
        _open,
        _high,
        _low,
        _close,
        _volume
    from {{ ref('stg_vnstock_stock_price') }}
),

calc_indicators as (
    select 
        *,
        (_close - lag(_close, 1) over w_all) / lag(_close, 1) over w_all * 100 as daily_return_pct,
        avg(_close) over w_20 as sma_20,
        stddevPop(_close) over w_20 as stddev_20,
        avg(_volume) over w_20 as volume_ma_20
    from base
    window 
        w_all as (partition by _ticker order by _date),
        w_20 as (partition by _ticker order by _date rows between 19 preceding and current row)
)

select
    _ticker,
    _date,
    _open, 
    _high, 
    _low, 
    _close, 
    _volume,
    
    round(daily_return_pct, 2) as daily_return_pct,
    round(sma_20, 2) as sma_20,
    round(sma_20 + (stddev_20 * 2), 2) as bb_upper,
    round(sma_20 - (stddev_20 * 2), 2) as bb_lower,
    round(volume_ma_20, 0) as volume_ma_20
from calc_indicators