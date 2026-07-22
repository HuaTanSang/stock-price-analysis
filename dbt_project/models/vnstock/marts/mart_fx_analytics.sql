{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['date', 'currency_code'],
        schema='marts'
    ) 
}}

with fx_with_prev as (
    select
        date,
        currency_code,
        currency_name,
        buy_cash,
        buy_transfer,
        sell,

        -- Previous day values
        lag(sell, 1) over w_curr as prev_sell,
        lag(buy_transfer, 1) over w_curr as prev_buy_transfer,

        -- Rolling averages
        avg(sell) over w_7  as sell_ma_7,
        avg(sell) over w_30 as sell_ma_30

    from {{ ref('stg_vnstock_exchange_rate') }}
    window
        w_curr as (partition by currency_code order by date),
        w_7    as (partition by currency_code order by date rows between  6 preceding and current row),
        w_30   as (partition by currency_code order by date rows between 29 preceding and current row)
)

select
    date,
    currency_code,
    currency_name,
    buy_cash,
    buy_transfer,
    sell,

    -- Buy-sell spread
    (sell - buy_transfer) as spread_vnd,
    round(
        cast((sell - buy_transfer) as Nullable(Float64)) 
        / nullIf(cast(buy_transfer as Nullable(Float64)), 0) * 100, 2
    ) as spread_margin_pct,

    -- Daily change (sell rate)
    (sell - prev_sell) as sell_daily_change,
    round(
        cast((sell - prev_sell) as Nullable(Float64)) 
        / nullIf(cast(prev_sell as Nullable(Float64)), 0) * 100, 4
    ) as sell_daily_change_pct,

    -- Rolling averages
    round(sell_ma_7, 2) as sell_ma_7,
    round(sell_ma_30, 2) as sell_ma_30

from fx_with_prev
