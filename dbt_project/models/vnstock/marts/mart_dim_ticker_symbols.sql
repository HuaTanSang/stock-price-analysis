{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['ticker', 'date'],
        schema='marts'
    ) 
}}

with dim_ticker_symbol as (
    select
        t1.symbol,
        t1.organ_name,

        t2.en_organ_name,
        t2.exchange,
        t2.type,
        t2.id,

        t3.com_code_type,
        t3.icb_level,
        t3.icb_code,
        t3.icb_name

    from {{ ref('stg_vnstock_ticker_symbols') }} as t1
    inner join {{ ref('stg_vnstock_ticker_symbols_by_exchange') }} as t2
    on t1.symbol = t2.symbol
    inner join {{ ref('stg_vnstock_ticker_symbols_by_industry') }}  AS t3
    on t1.symbol = t3.symbol;
)


select * from dim_ticker_symbol