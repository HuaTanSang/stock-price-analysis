{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_date'],
        schema='marts'
    ) 
}}

-- Cross-domain macro overview: market index + gold + USD on the same time axis
with vnindex as (
    select 
        _date, 
        _close as vnindex_close,
        (_close - lag(_close, 1) over (order by _date)) 
            / nullIf(lag(_close, 1) over (order by _date), 0) * 100 
            as vnindex_daily_pct
    from {{ ref('stg_vnstock_market_index') }}
    where _index_symbol = 'VNINDEX'
),

vn30 as (
    select 
        _date, 
        _close as vn30_close,
        (_close - lag(_close, 1) over (order by _date)) 
            / nullIf(lag(_close, 1) over (order by _date), 0) * 100 
            as vn30_daily_pct
    from {{ ref('stg_vnstock_market_index') }}
    where _index_symbol = 'VN30'
),

usd_fx as (
    select 
        _date, 
        _sell as usd_sell_rate,
        (_sell - lag(_sell, 1) over (order by _date)) 
            / nullIf(lag(_sell, 1) over (order by _date), 0) * 100 
            as usd_daily_pct
    from {{ ref('stg_vnstock_exchange_rate') }}
    where _currency_code = 'USD'
),

gold_sjc as (
    select 
        _date, 
        _sell_price as gold_sjc_sell,
        (_sell_price - lag(_sell_price, 1) over (order by _date)) 
            / nullIf(lag(_sell_price, 1) over (order by _date), 0) * 100 
            as gold_daily_pct
    from {{ ref('stg_vnstock_gold_price') }}
    where _branch = 'Hồ Chí Minh' 
      and _name = 'Vàng SJC 1L, 10L, 1KG'
)

select
    coalesce(vi._date, v3._date, f._date, g._date) as _date,

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
full outer join vn30 v3 on vi._date = v3._date
full outer join usd_fx f on coalesce(vi._date, v3._date) = f._date
full outer join gold_sjc g on coalesce(vi._date, v3._date, f._date) = g._date
