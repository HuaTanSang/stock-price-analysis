{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_date'],
        schema='marts'
    ) 
}}

select
    _date,
    _name,
    _branch,
    _buy_price,
    _sell_price,
    (_sell_price - _buy_price) as spread_vnd,
    round(cast((_sell_price - _buy_price) as Float64) / _buy_price * 100, 2) as spread_margin_pct
from {{ ref('stg_vnstock_gold_price') }}