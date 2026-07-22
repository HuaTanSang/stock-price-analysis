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

    from raw_vnstock_ticker_symbol as t1
    inner join raw_vnstock_ticker_symbol_by_exchange as t2
    on t1.symbol = t2.symbol
    inner join raw_vnstock_ticker_symbol_by_icb AS t3
    on t1.symbol = t3.symbol;
), 

base as (
    select
        sp.ticker,
        sp.date,
        sp.open,
        sp.high,
        sp.low,
        sp.close,
        sp.volume,
        sp.interval,
        ts.organ_name,
        ts.industry_name,
        ts.en_industry_name,
        ts.sector,
        ts.en_sector,
        ts.exchange
    from {{ ref('stg_vnstock_stock_price') }} sp
    left join dim_ticker_symbol ts
        on sp.ticker = ts.ticker
),

-- Phase 1: Tính toán các chỉ báo cơ sở, True Range và gắn số dòng để xử lý warm-up
calc_base_metrics as (
    select 
        *,
        -- Số thứ tự dòng theo từng mã để kiểm soát thời gian khởi tạo (warm-up)
        row_number() over (partition by ticker order by date) as row_num,  

        -- Daily Returns
       ((close * 1.0 - lagInFrame(close, 1, close) over w_ticker) 
            / nullIf(lagInFrame(close, 1, close) over w_ticker, 0)) * 100.0 
            as daily_return_pct, 

        -- Typical Price (Nền tảng cho VWAP)
        (high + low + close) / 3 as typical_price,

        -- True Range chuẩn hóa với lagInFrame tránh lỗi biên dữ liệu
        greatest(
            high - low,
            abs(high - lagInFrame(close, 1, high) over w_ticker),
            abs(low  - lagInFrame(close, 1, low) over w_ticker)
        ) as true_range,  

        -- RSI building blocks
        if(close > lagInFrame(close, 1, close) over w_ticker, close - lagInFrame(close, 1, close) over w_ticker, 0) as gain, -- checked 
        if(close < lagInFrame(close, 1, close) over w_ticker, lagInFrame(close, 1, close) over w_ticker - close, 0) as loss -- checked 
    from base
    window 
        w_ticker as (partition by ticker order by date)
),

-- Phase 2: Áp dụng Window Functions kèm điều kiện loại bỏ nhiễu giai đoạn đầu (Warm-up Filter)
calc_windows as (
    select
        *,
        -- Simple Moving Averages (SMA) - Chỉ trả về giá trị khi đủ số phiên dữ liệu
        if(row_num >= 5, avg(close) over w_5, null) as sma_5,
        if(row_num >= 20, avg(close) over w_20, null) as sma_20,
        if(row_num >= 50, avg(close) over w_50, null) as sma_50,

        -- Đường trung bình phục vụ tính MACD xấp xỉ
        if(row_num >= 12, avg(close) over w_12, null) as sma_12,
        if(row_num >= 26, avg(close) over w_26, null) as sma_26,

        -- Bollinger Bands Standard Deviation
        if(row_num >= 20, stddevPop(close) over w_20, null) as stddev_20,

        -- Volume Moving Average
        if(row_num >= 20, avg(volume) over w_20, null) as volume_ma_20,

        -- 52-week High/Low (252 ngày giao dịch)
        if(row_num >= 252, max(high) over w_252, null) as high_52w,
        if(row_num >= 252, min(low) over w_252, null) as low_52w,

        -- Cumulative return tính từ ngày đầu tiên lên sàn có trong hệ thống
        (close - first_value(close) over w_ticker) 
            / nullIf(first_value(close) over w_ticker, 0) * 100 
            as cumulative_return_pct,

        -- SỬA LỖI: Rolling VWAP 20 ngày chuẩn có trọng số khối lượng
        if(row_num >= 20, 
            sum(typical_price * volume) over w_20 / nullIf(sum(volume) over w_20, 0), 
            null
        ) as vwap_20_rolling,

        -- RSI-14 averages (Phương pháp Cutler RSI)
        if(row_num >= 14, avg(gain) over w_14, null) as avg_gain_14,
        if(row_num >= 14, avg(loss) over w_14, null) as avg_loss_14,

        -- Average True Range (ATR-14)
        if(row_num >= 14, avg(true_range) over w_14, null) as atr_14

    from calc_base_metrics
    window 
        w_ticker as (partition by ticker order by date),
        w_5      as (partition by ticker order by date rows between  4 preceding and current row),
        w_12     as (partition by ticker order by date rows between 11 preceding and current row),
        w_14     as (partition by ticker order by date rows between 13 preceding and current row),
        w_20     as (partition by ticker order by date rows between 19 preceding and current row),
        w_26     as (partition by ticker order by date rows between 25 preceding and current row),
        w_50     as (partition by ticker order by date rows between 49 preceding and current row),
        w_252    as (partition by ticker order by date rows between 251 preceding and current row)
)

-- Phase 3: Bo tròn kết quả và xử lý logic tầng cuối
select
    ticker,
    date,
    interval,
    open, 
    high, 
    low, 
    close, 
    volume,

    -- Thông tin tham chiếu
    organ_name,
    industry_name,
    en_industry_name,
    sector,
    en_sector,
    exchange,

    -- Hiệu suất tỷ suất sinh lời
    round(daily_return_pct, 2) as daily_return_pct,
    round(cumulative_return_pct, 2) as cumulative_return_pct,

    -- Xu hướng (Moving Averages)
    round(sma_5, 2) as sma_5,
    round(sma_20, 2) as sma_20,
    round(sma_50, 2) as sma_50,
    round(sma_12 - sma_26, 2) as macd_sma_diff, -- Đổi tên rõ nghĩa vì dùng SMA thay vì EMA

    -- Dải Bollinger Bands
    round(sma_20 + (stddev_20 * 2), 2) as bb_upper,
    round(sma_20 - (stddev_20 * 2), 2) as bb_lower,

    -- Động lượng (RSI-14)
    round(
        if(avg_loss_14 = 0, 100,
           100 - (100 / (1 + avg_gain_14 / nullIf(avg_loss_14, 0)))
        ), 2
    ) as rsi_14,

    -- Biến động và Giá trọng số
    round(atr_14, 2) as atr_14,
    round(vwap_20_rolling, 2) as vwap_20_rolling,

    -- Khung giá 52 tuần
    round(high_52w, 2) as high_52w,
    round(low_52w, 2) as low_52w,

    -- Khối lượng giao dịch
    round(volume_ma_20, 0) as volume_ma_20,
    if(volume_ma_20 = 0 or isNull(volume_ma_20), null, 
       round(cast(_volume as Float64) / volume_ma_20, 2)
    ) as volume_ratio

from calc_windows