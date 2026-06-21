{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_date', '_currency_code'],
        schema='marts'
    ) 
}}

with fx_with_prev as (
    select
        _date,
        _currency_code,
        _currency_name,
        _buy_cash,
        _buy_transfer,
        _sell,

        -- Previous day values
        lag(_sell, 1) over w_curr as prev_sell,
        lag(_buy_transfer, 1) over w_curr as prev_buy_transfer,

        -- Rolling averages
        avg(_sell) over w_7  as sell_ma_7,
        avg(_sell) over w_30 as sell_ma_30

    from {{ ref('stg_vnstock_exchange_rate') }}
    window
        w_curr as (partition by _currency_code order by _date),
        w_7    as (partition by _currency_code order by _date rows between  6 preceding and current row),
        w_30   as (partition by _currency_code order by _date rows between 29 preceding and current row)
)

select
    _date,
    _currency_code,
    _currency_name,
    _buy_cash,
    _buy_transfer,
    _sell,

    -- Buy-sell spread
    (_sell - _buy_transfer) as spread_vnd,
    round(
        cast((_sell - _buy_transfer) as Nullable(Float64)) 
        / nullIf(cast(_buy_transfer as Nullable(Float64)), 0) * 100, 2
    ) as spread_margin_pct,

    -- Daily change (sell rate)
    (_sell - prev_sell) as sell_daily_change,
    round(
        cast((_sell - prev_sell) as Nullable(Float64)) 
        / nullIf(cast(prev_sell as Nullable(Float64)), 0) * 100, 4
    ) as sell_daily_change_pct,

    -- Rolling averages
    round(sell_ma_7, 2) as sell_ma_7,
    round(sell_ma_30, 2) as sell_ma_30

from fx_with_prev
