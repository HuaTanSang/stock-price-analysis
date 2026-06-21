{{ 
    config(
        materialized='table',
        engine='MergeTree()',
        order_by=['_ticker', '_date'],
        schema='marts'
    ) 
}}

with base as (
    select
        sp._ticker,
        sp._date,
        sp._open,
        sp._high,
        sp._low,
        sp._close,
        sp._volume,
        sp._interval,
        ts._organ_name,
        ts._industry_name,
        ts._en_industry_name,
        ts._sector,
        ts._en_sector,
        ts._exchange
    from {{ ref('stg_vnstock_stock_price') }} sp
    left join {{ ref('stg_vnstock_ticker_symbols') }} ts
        on sp._ticker = ts._ticker
),

-- Technical indicators using window functions
calc_indicators as (
    select 
        *,

        -- ── Daily Returns ──
        (_close - lag(_close, 1) over w_ticker) 
            / nullIf(lag(_close, 1) over w_ticker, 0) * 100 
            as daily_return_pct,

        -- ── Simple Moving Averages ──
        avg(_close) over w_5 as sma_5,
        avg(_close) over w_20 as sma_20,
        avg(_close) over w_50 as sma_50,

        -- ── Exponential Moving Average approximations ──
        -- EMA cannot be computed exactly in SQL, but SMA over these windows
        -- provides a close enough approximation for dashboard use
        avg(_close) over w_12 as ema_12_approx,
        avg(_close) over w_26 as ema_26_approx,

        -- ── Bollinger Bands (20-day) ──
        stddevPop(_close) over w_20 as stddev_20,

        -- ── Volume analysis ──
        avg(_volume) over w_20 as volume_ma_20,

        -- ── Volatility: True Range & ATR-14 ──
        greatest(
            _high - _low,
            abs(_high - coalesce(lag(_close, 1) over w_ticker, _high)),
            abs(_low  - coalesce(lag(_close, 1) over w_ticker, _low))
        ) as true_range,

        -- ── 52-week (252 trading day) high/low ──
        max(_high) over w_252 as high_52w,
        min(_low)  over w_252 as low_52w,

        -- ── Cumulative return from first known date ──
        (_close - first_value(_close) over w_ticker) 
            / nullIf(first_value(_close) over w_ticker, 0) * 100 
            as cumulative_return_pct,

        -- ── VWAP approximation (typical price) ──
        (_high + _low + _close) / 3 as vwap_approx,

        -- ── RSI-14 building blocks ──
        -- Gain/Loss vs previous close
        if(
            _close > lag(_close, 1) over w_ticker,
            _close - lag(_close, 1) over w_ticker,
            0
        ) as _gain,
        if(
            _close < lag(_close, 1) over w_ticker,
            lag(_close, 1) over w_ticker - _close,
            0
        ) as _loss

    from base
    window 
        w_ticker as (partition by _ticker order by _date),
        w_5      as (partition by _ticker order by _date rows between  4 preceding and current row),
        w_12     as (partition by _ticker order by _date rows between 11 preceding and current row),
        w_20     as (partition by _ticker order by _date rows between 19 preceding and current row),
        w_26     as (partition by _ticker order by _date rows between 25 preceding and current row),
        w_50     as (partition by _ticker order by _date rows between 49 preceding and current row),
        w_252    as (partition by _ticker order by _date rows between 251 preceding and current row)
),

-- Second pass to compute RSI and ATR which need the values from the first pass
with_rsi as (
    select
        *,
        -- Average gain/loss over 14 periods for RSI
        avg(_gain) over w_14 as avg_gain_14,
        avg(_loss) over w_14 as avg_loss_14,
        -- ATR-14
        avg(true_range) over w_14 as atr_14
    from calc_indicators
    window 
        w_14 as (partition by _ticker order by _date rows between 13 preceding and current row)
)

select
    _ticker,
    _date,
    _interval,
    _open, 
    _high, 
    _low, 
    _close, 
    _volume,

    -- Reference data
    _organ_name,
    _industry_name,
    _en_industry_name,
    _sector,
    _en_sector,
    _exchange,

    -- Returns
    round(daily_return_pct, 2) as daily_return_pct,
    round(cumulative_return_pct, 2) as cumulative_return_pct,

    -- Moving averages
    round(sma_5, 2) as sma_5,
    round(sma_20, 2) as sma_20,
    round(sma_50, 2) as sma_50,

    -- MACD approximation (EMA12 - EMA26)
    round(ema_12_approx - ema_26_approx, 2) as macd_approx,

    -- Bollinger Bands
    round(sma_20 + (stddev_20 * 2), 2) as bb_upper,
    round(sma_20 - (stddev_20 * 2), 2) as bb_lower,

    -- RSI-14 (0–100 scale)
    round(
        if(avg_loss_14 = 0, 100,
           100 - (100 / (1 + avg_gain_14 / nullIf(avg_loss_14, 0)))
        ), 2
    ) as rsi_14,

    -- Volatility
    round(atr_14, 2) as atr_14,
    round(vwap_approx, 2) as vwap_approx,

    -- 52-week range
    round(high_52w, 2) as high_52w,
    round(low_52w, 2) as low_52w,

    -- Volume analysis
    round(volume_ma_20, 0) as volume_ma_20,
    if(volume_ma_20 = 0, null, 
       round(cast(_volume as Float64) / volume_ma_20, 2)
    ) as volume_ratio

from with_rsi
