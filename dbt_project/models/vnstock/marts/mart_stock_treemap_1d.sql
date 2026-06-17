{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_date'],
        schema='marts'
    ) 
}}

with calc_performance as (
    select
        _ticker,
        _date,
        _close,
        (_close - lag(_close, 1) over w_all) / lag(_close, 1) over w_all * 100 as daily_return_pct
    from {{ ref('stg_vnstock_stock_price') }}
    where _interval = '1D'
    window 
        w_all as (partition by _ticker order by _date)
)

select
    _date,
    _ticker,
    _close,
    round(daily_return_pct, 2) as daily_return_pct,
    abs(round(daily_return_pct, 2)) as change_magnitude_size
from calc_performance
where daily_return_pct is not null