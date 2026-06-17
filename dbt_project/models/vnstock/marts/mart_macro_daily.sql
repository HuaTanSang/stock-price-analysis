{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_date'],
        schema='marts'
    ) 
}}

with usd_fx as (
    select _date, _sell as usd_sell_rate
    from {{ ref('stg_vnstock_exchange_rate') }}
    where _currency_code = 'USD'
),

gold_hcm as (
    select _date, _sell_price as gold_hcm_sell
    from {{ ref('stg_vnstock_gold_price') }}
    where _branch = 'Hồ Chí Minh' 
      and _name = 'Vàng SJC 1L, 10L, 1KG'
),

vcb_stock as (
    select _date, _close as vcb_close_price
    from {{ ref('stg_vnstock_stock_price') }}
    where _ticker = 'VCB'
)

select
    coalesce(f._date, g._date, s._date) as _date,
    f.usd_sell_rate,
    g.gold_hcm_sell,
    s.vcb_close_price
from usd_fx f
full outer join gold_hcm g on f._date = g._date
full outer join vcb_stock s on f._date = s._date