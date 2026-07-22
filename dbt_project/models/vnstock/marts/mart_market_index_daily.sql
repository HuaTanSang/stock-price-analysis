{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['index_symbol', 'date'],
        schema='marts'
    ) 
}}

with base as (
    select
        index_symbol,
        date,
        open,
        high,
        low,
        close,
        volume
    from {{ ref('stg_vnstock_market_index') }}
),

calc_indicators as (
    select 
        *,

        -- Daily return
        (close - lag(close, 1) over w_idx) 
            / nullIf(lag(close, 1) over w_idx, 0) * 100 
            as daily_return_pct,

        -- Point change
        (close - lag(close, 1) over w_idx) as daily_point_change,

        -- Moving averages
        avg(close) over w_5  as sma_5,
        avg(close) over w_20 as sma_20,
        avg(close) over w_50 as sma_50,

        -- Volume analysis
        avg(volume) over w_20 as volume_ma_20,

        -- 52-week high/low
        max(high) over w_252 as high_52w,
        min(low)  over w_252 as low_52w,

        -- Cumulative return from first date
        (close - first_value(close) over w_idx) 
            / nullIf(first_value(close) over w_idx, 0) * 100 
            as cumulative_return_pct

    from base
    window 
        w_idx as (partition by index_symbol order by date),
        w_5   as (partition by index_symbol order by date rows between  4 preceding and current row),
        w_20  as (partition by index_symbol order by date rows between 19 preceding and current row),
        w_50  as (partition by index_symbol order by date rows between 49 preceding and current row),
        w_252 as (partition by index_symbol order by date rows between 251 preceding and current row)
)

select
    index_symbol,
    date,
    open,
    high,
    low,
    close,
    volume,

    round(daily_point_change, 2) as daily_point_change,
    round(daily_return_pct, 2) as daily_return_pct,
    round(cumulative_return_pct, 2) as cumulative_return_pct,

    round(sma_5, 2) as sma_5,
    round(sma_20, 2) as sma_20,
    round(sma_50, 2) as sma_50,

    round(high_52w, 2) as high_52w,
    round(low_52w, 2) as low_52w,

    round(volume_ma_20, 0) as volume_ma_20,
    if(volume_ma_20 = 0, null,
       round(cast(volume as Float64) / volume_ma_20, 2)
    ) as volume_ratio

from calc_indicators
