{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_date', '_branch', '_name'],
        schema='marts'
    ) 
}}

with gold_with_prev as (
    select
        _date,
        _name,
        _branch,
        _buy_price,
        _sell_price,

        -- Previous day prices for change calculation
        lag(_buy_price, 1) over (partition by _branch, _name order by _date) as prev_buy_price,
        lag(_sell_price, 1) over (partition by _branch, _name order by _date) as prev_sell_price,

        -- Rolling averages
        avg(_sell_price) over w_7  as sell_price_ma_7,
        avg(_sell_price) over w_30 as sell_price_ma_30,
        avg(_buy_price) over w_7  as buy_price_ma_7,
        avg(_buy_price) over w_30 as buy_price_ma_30

    from {{ ref('stg_vnstock_gold_price') }}
    window
        w_7  as (partition by _branch, _name order by _date rows between  6 preceding and current row),
        w_30 as (partition by _branch, _name order by _date rows between 29 preceding and current row)
)

select
    _date,
    _name,
    _branch,
    _buy_price,
    _sell_price,

    -- Spread analysis
    (_sell_price - _buy_price) as spread_vnd,
    round(
        cast((_sell_price - _buy_price) as Nullable(Float64)) 
        / nullIf(cast(_buy_price as Nullable(Float64)), 0) * 100, 2
    ) as spread_margin_pct,

    -- Daily changes
    (_sell_price - prev_sell_price) as sell_daily_change,
    round(
        cast((_sell_price - prev_sell_price) as Nullable(Float64)) 
        / nullIf(cast(prev_sell_price as Nullable(Float64)), 0) * 100, 2
    ) as sell_daily_change_pct,
    
    (_buy_price - prev_buy_price) as buy_daily_change,
    round(
        cast((_buy_price - prev_buy_price) as Nullable(Float64)) 
        / nullIf(cast(prev_buy_price as Nullable(Float64)), 0) * 100, 2
    ) as buy_daily_change_pct,

    -- Rolling averages
    round(sell_price_ma_7, 0) as sell_price_ma_7,
    round(sell_price_ma_30, 0) as sell_price_ma_30,
    round(buy_price_ma_7, 0) as buy_price_ma_7,
    round(buy_price_ma_30, 0) as buy_price_ma_30

from gold_with_prev
