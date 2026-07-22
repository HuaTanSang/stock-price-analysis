{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['date'],
        schema='marts'
    ) 
}}

-- Cross-domain macro overview: market index + gold + USD on the same time axis
with vnindex as (
    select 
        date, 
        close as vnindex_close,
        (close - lag(close, 1) over (order by date)) 
            / nullIf(lag(close, 1) over (order by date), 0) * 100 
            as vnindex_daily_pct
    from {{ ref('stg_vnstock_market_index') }}
    where index_symbol = 'VNINDEX'
),

vn30 as (
    select 
        date, 
        close as vn30_close,
        (close - lag(close, 1) over (order by date)) 
            / nullIf(lag(close, 1) over (order by date), 0) * 100 
            as vn30_daily_pct
    from {{ ref('stg_vnstock_market_index') }}
    where index_symbol = 'VN30'
),

usd_fx as (
    select 
        date, 
        sell as usd_sell_rate,
        (sell - lag(sell, 1) over (order by date)) 
            / nullIf(lag(sell, 1) over (order by date), 0) * 100 
            as usd_daily_pct
    from {{ ref('stg_vnstock_exchange_rate') }}
    where currency_code = 'USD'
),

gold_sjc as (
    select 
        date, 
        sell_price as gold_sjc_sell,
        (sell_price - lag(sell_price, 1) over (order by date)) 
            / nullIf(lag(sell_price, 1) over (order by date), 0) * 100 
            as gold_daily_pct
    from {{ ref('stg_vnstock_gold_price') }}
    where _branch = 'Hồ Chí Minh' 
      and _name = 'Vàng SJC 1L, 10L, 1KG'
)

select
    coalesce(vi.date, v3.date, f.date, g.date) as date,

    -- VNINDEX
    vi.vnindex_close,
    round(vi.vnindex_daily_pct, 2) as vnindex_daily_pct,

    -- VN30
    v3.vn30_close,
    round(v3.vn30_daily_pct, 2) as vn30_daily_pct,

    -- USD/VND
    f.usd_sell_rate,
    round(f.usd_daily_pct, 4) as usd_daily_pct,

    -- Gold SJC
    g.gold_sjc_sell,
    round(g.gold_daily_pct, 2) as gold_daily_pct,

    -- Gold-to-USD ratio (international parity indicator)
    if(f.usd_sell_rate is not null and f.usd_sell_rate != 0,
       round(cast(g.gold_sjc_sell as Nullable(Float64)) / cast(f.usd_sell_rate as Nullable(Float64)), 2),
       null
    ) as gold_usd_ratio

from vnindex vi
full outer join vn30 v3 on vi.date = v3.date
full outer join usd_fx f on coalesce(vi.date, v3.date) = f.date
full outer join gold_sjc g on coalesce(vi.date, v3.date, f.date) = g.date
