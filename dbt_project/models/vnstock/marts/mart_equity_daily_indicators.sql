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

-- Phase 1: Tính toán các chỉ báo cơ sở, True Range và gắn số dòng để xử lý warm-up
calc_base_metrics as (
    select 
        *,
        -- Số thứ tự dòng theo từng mã để kiểm soát thời gian khởi tạo (warm-up)
        row_number() over (partition by _ticker order by _date) as row_num,  

        -- Daily Returns
       ((_close * 1.0 - lagInFrame(_close, 1, _close) over w_ticker) 
            / nullIf(lagInFrame(_close, 1, _close) over w_ticker, 0)) * 100.0 
            as daily_return_pct, 

        -- Typical Price (Nền tảng cho VWAP)
        (_high + _low + _close) / 3 as typical_price,

        -- True Range chuẩn hóa với lagInFrame tránh lỗi biên dữ liệu
        greatest(
            _high - _low,
            abs(_high - lagInFrame(_close, 1, _high) over w_ticker),
            abs(_low  - lagInFrame(_close, 1, _low) over w_ticker)
        ) as true_range,  

        -- RSI building blocks
        if(_close > lagInFrame(_close, 1, _close) over w_ticker, _close - lagInFrame(_close, 1, _close) over w_ticker, 0) as _gain, -- checked 
        if(_close < lagInFrame(_close, 1, _close) over w_ticker, lagInFrame(_close, 1, _close) over w_ticker - _close, 0) as _loss -- checked 
    from base
    window 
        w_ticker as (partition by _ticker order by _date)
),

-- Phase 2: Áp dụng Window Functions kèm điều kiện loại bỏ nhiễu giai đoạn đầu (Warm-up Filter)
calc_windows as (
    select
        *,
        -- Simple Moving Averages (SMA) - Chỉ trả về giá trị khi đủ số phiên dữ liệu
        if(row_num >= 5, avg(_close) over w_5, null) as sma_5,
        if(row_num >= 20, avg(_close) over w_20, null) as sma_20,
        if(row_num >= 50, avg(_close) over w_50, null) as sma_50,

        -- Đường trung bình phục vụ tính MACD xấp xỉ
        if(row_num >= 12, avg(_close) over w_12, null) as sma_12,
        if(row_num >= 26, avg(_close) over w_26, null) as sma_26,

        -- Bollinger Bands Standard Deviation
        if(row_num >= 20, stddevPop(_close) over w_20, null) as stddev_20,

        -- Volume Moving Average
        if(row_num >= 20, avg(_volume) over w_20, null) as volume_ma_20,

        -- 52-week High/Low (252 ngày giao dịch)
        if(row_num >= 252, max(_high) over w_252, null) as high_52w,
        if(row_num >= 252, min(_low) over w_252, null) as low_52w,

        -- Cumulative return tính từ ngày đầu tiên lên sàn có trong hệ thống
        (_close - first_value(_close) over w_ticker) 
            / nullIf(first_value(_close) over w_ticker, 0) * 100 
            as cumulative_return_pct,

        -- SỬA LỖI: Rolling VWAP 20 ngày chuẩn có trọng số khối lượng
        if(row_num >= 20, 
            sum(typical_price * _volume) over w_20 / nullIf(sum(_volume) over w_20, 0), 
            null
        ) as vwap_20_rolling,

        -- RSI-14 averages (Phương pháp Cutler RSI)
        if(row_num >= 14, avg(_gain) over w_14, null) as avg_gain_14,
        if(row_num >= 14, avg(_loss) over w_14, null) as avg_loss_14,

        -- Average True Range (ATR-14)
        if(row_num >= 14, avg(true_range) over w_14, null) as atr_14

    from calc_base_metrics
    window 
        w_ticker as (partition by _ticker order by _date),
        w_5      as (partition by _ticker order by _date rows between  4 preceding and current row),
        w_12     as (partition by _ticker order by _date rows between 11 preceding and current row),
        w_14     as (partition by _ticker order by _date rows between 13 preceding and current row),
        w_20     as (partition by _ticker order by _date rows between 19 preceding and current row),
        w_26     as (partition by _ticker order by _date rows between 25 preceding and current row),
        w_50     as (partition by _ticker order by _date rows between 49 preceding and current row),
        w_252    as (partition by _ticker order by _date rows between 251 preceding and current row)
)

-- Phase 3: Bo tròn kết quả và xử lý logic tầng cuối
select
    _ticker,
    _date,
    _interval,
    _open, 
    _high, 
    _low, 
    _close, 
    _volume,

    -- Thông tin tham chiếu
    _organ_name,
    _industry_name,
    _en_industry_name,
    _sector,
    _en_sector,
    _exchange,

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