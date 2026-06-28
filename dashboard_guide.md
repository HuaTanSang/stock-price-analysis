# Dashboard Construction Guide

## Available Data Models (ClickHouse `marts` schema)

| # | Model | Granularity | Key Columns |
|---|-------|-------------|-------------|
| 1 | `mart_equity_daily_indicators` | ticker × date | OHLCV, SMA-5/20/50, RSI-14, MACD, Bollinger Bands, ATR-14, VWAP, 52w H/L, volume_ratio, industry/sector |
| 2 | `mart_equity_treemap` | ticker × date | daily_return_pct, turnover_proxy, industry/sector classification |
| 3 | `mart_market_index_daily` | index × date | OHLCV, SMA-5/20/50, 52w H/L, point_change, volume_ratio (VNINDEX, VN30, HNXINDEX) |
| 4 | `mart_gold_analytics` | branch × name × date | buy/sell prices, spread, daily changes (%), 7/30-day MA |
| 5 | `mart_fx_analytics` | currency × date | buy_cash, buy_transfer, sell, spread, daily changes (%), 7/30-day MA |
| 6 | `mart_macro_overview` | date | VNINDEX, VN30, USD/VND, Gold SJC — all on same time axis + gold_usd_ratio |
| 7 | `mart_fundamental_ratios` | ticker × year × quarter | ROE, ROA, margins, D/E, EPS, P/E, revenue growth, cash flows |

---

## Tool Strategy: Superset vs Grafana

| Capability | Superset ✅ | Grafana ✅ |
|------------|------------|-----------|
| **Pie / Donut charts** | ✅ Excellent | ⚠️ Basic |
| **Treemap** | ✅ Built-in | ❌ Requires plugin |
| **Bar / Area / Line charts** | ✅ Great | ✅ Great |
| **Heatmaps** | ✅ Good | ✅ Excellent |
| **Candlestick** | ❌ Not available | ✅ Built-in (via native Candlestick panel) |
| **Multi-panel layouts** | ⚠️ Tabs only | ✅ Excellent (rows, panels, variables) |
| **Template variables / filters** | ⚠️ Filters only | ✅ Excellent ($ticker, $date_range) |
| **Time series monitoring** | ⚠️ Ok | ✅ Purpose-built |
| **SQL freedom** | ✅ Full SQL Lab | ✅ Full via ClickHouse datasource |
| **Table/Pivot** | ✅ Excellent | ⚠️ Basic |

### Recommendation

> [!TIP]
> **Use Superset** for static analytical dashboards (fundamentals, treemap, macro comparisons).
> **Use Grafana** for real-time monitoring dashboards (stock prices, candlesticks, market indices, alerts).

---

## GRAFANA DASHBOARDS

### Connection Setup

1. Go to **Connections → Data Sources → Add data source**
2. Search for **ClickHouse**
3. Configure:
   - **Server address**: `clickhouse`
   - **Server port**: `9000` (native) or `8123` (HTTP)
   - **Database**: `marts`
   - **Username/Password**: as configured

### Dashboard 1: Stock Technical Analysis (Candlestick + Indicators)

> [!IMPORTANT]
> This is the dashboard that **cannot** be built in Superset due to the candlestick limitation.

**Template Variables** (add at dashboard Settings → Variables):

| Variable | Type | Query |
|----------|------|-------|
| `ticker` | Query | `SELECT DISTINCT _ticker FROM marts.mart_equity_daily_indicators ORDER BY _ticker` |
| `interval` | Custom | `1D,1W` |

---

#### Panel 1: Candlestick + SMA overlay (Candlestick panel)

```sql
SELECT
    _date AS time,
    _open AS open,
    _high AS high,
    _low AS low,
    _close AS close,
    _volume AS volume
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker'
  AND _interval = '$interval'
  AND _date >= $__fromTime
  AND _date <= $__toTime
ORDER BY _date
```

```sql 
SELECT
    toStartOfInterval(toDateTime(_date), toIntervalSecond($__interval_s)) AS time,
    argMin(_open, _date) AS open,
    max(_high) AS high,
    min(_low) AS low,
    argMax(_close, _date) AS close,
    sum(_volume) AS volume
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker'
  AND _interval = '$interval'
  AND $__timeFilter(_date)
GROUP BY time
ORDER BY time
```


- Panel type: **Candlestick**
- Color scheme: Up=Green, Down=Red

**SMA overlays** (add as separate queries in the same panel):

```sql
-- Query B: SMA lines
SELECT
    _date AS time,
    sma_5 AS "SMA-5",
    sma_20 AS "SMA-20",
    sma_50 AS "SMA-50"
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker'
  AND _interval = '$interval'
  AND _date >= $__fromTime
  AND _date <= $__toTime
ORDER BY _date
```

**Bollinger Bands** (Query C):

```sql
SELECT
    _date AS time,
    bb_upper AS "BB Upper",
    sma_20 AS "BB Middle",
    bb_lower AS "BB Lower"
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker'
  AND _interval = '$interval'
  AND _date >= $__fromTime
  AND _date <= $__toTime
ORDER BY _date
```

---

#### Panel 2: Volume Bar Chart (Bar chart panel)

```sql
SELECT
    _date AS time,
    _volume AS "Volume",
    volume_ma_20 AS "Volume MA-20"
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker'
  AND _interval = '$interval'
  AND _date >= $__fromTime
  AND _date <= $__toTime
ORDER BY _date
```

- Panel type: **Time series** with bars for volume, line for MA-20
- Place directly below the candlestick panel

---

#### Panel 3: RSI-14 (Time series panel)

```sql
SELECT
    _date AS time,
    rsi_14 AS "RSI-14"
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker'
  AND _interval = '$interval'
  AND _date >= $__fromTime
  AND _date <= $__toTime
ORDER BY _date
```

- Add **constant thresholds** at 30 (green/oversold) and 70 (red/overbought)
- Y-axis: 0–100 fixed

---

#### Panel 4: MACD (Time series panel)

```sql
SELECT
    _date AS time,
    macd_approx AS "MACD"
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker'
  AND _interval = '$interval'
  AND _date >= $__fromTime
  AND _date <= $__toTime
ORDER BY _date

SELECT
    toStartOfInterval(toDateTime(_date), toIntervalSecond($__interval_s)) AS time,
    argMax(macd_approx, _date) AS "MACD"
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker'
  AND _interval = '$interval'
  AND $__timeFilter(_date)
GROUP BY time
ORDER BY time
```

- Use bar display with color by value (positive=green, negative=red)

---

#### Panel 5: Key Stats (Stat panels — a row of small panels)

```sql
-- Current price
SELECT _close AS "Price" FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker' AND _interval = '$interval'
ORDER BY _date DESC LIMIT 1

SELECT 
    _close AS "Price" 
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker' 
  AND _interval = '$interval'
  AND $__timeFilter(_date)
ORDER BY _date DESC 
LIMIT 1


```

```sql
-- Daily return %
SELECT daily_return_pct AS "Daily Return %" FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker' AND _interval = '$interval'
ORDER BY _date DESC LIMIT 1

SELECT 
    daily_return_pct AS "Daily Return %" 
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker' 
  AND _interval = '$interval'
  AND $__timeFilter(_date)
ORDER BY _date DESC 
LIMIT 1
```

```sql
-- 52-week High/Low
SELECT high_52w AS "52W High", low_52w AS "52W Low"
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker' AND _interval = '$interval'
ORDER BY _date DESC LIMIT 1

SELECT 
    high_52w AS "52W High", 
    low_52w AS "52W Low"
FROM marts.mart_equity_daily_indicators
WHERE _ticker = '$ticker' 
  AND _interval = '$interval'
  AND $__timeFilter(_date)
ORDER BY _date DESC 
LIMIT 1
```

---

#### Suggested Layout

```
┌──────────────────────────────────────────────┐
│ [Stat: Price] [Stat: Return%] [Stat: 52W HL]│  ← Row 1: Key stats
├──────────────────────────────────────────────┤
│                                              │
│        Candlestick + SMA + BB                │  ← Row 2: Main chart (height ~12)
│                                              │
├──────────────────────────────────────────────┤
│        Volume Bar Chart                      │  ← Row 3: Volume (height ~4)
├──────────────────────────────────────────────┤
│    RSI-14         │       MACD               │  ← Row 4: Oscillators (height ~4)
└──────────────────────────────────────────────┘
```

---

### Dashboard 2: Market Index Monitor

**Template Variable**: `index_symbol` = Custom: `VNINDEX, VN30, HNXINDEX, HNX30, UPCOM`

#### Panel 1: Index Candlestick

```sql
SELECT
    _date AS time,
    _open AS open, _high AS high, _low AS low, _close AS close
FROM marts.mart_market_index_daily
WHERE _index_symbol = '$index_symbol'
  AND _date >= $__fromTime AND _date <= $__toTime
ORDER BY _date
```

#### Panel 2: Multi-Index Comparison (Time series)

```sql
SELECT
    _date AS time,
    cumulative_return_pct AS "$index_symbol"
FROM marts.mart_market_index_daily
WHERE _index_symbol IN ('VNINDEX', 'VN30')
  AND _date >= $__fromTime AND _date <= $__toTime
ORDER BY _date
```

- Use this to compare normalized returns across indices on the same scale

#### Panel 3: Daily Point Change (Bar gauge)

```sql
SELECT daily_point_change AS "Point Change"
FROM marts.mart_market_index_daily
WHERE _index_symbol = '$index_symbol'
ORDER BY _date DESC LIMIT 1
```

---

### Dashboard 3: Macro Overview (Multi-asset)

Source: `mart_macro_overview`

#### Panel 1: Dual Y-axis — VNINDEX + Gold SJC

```sql
SELECT
    _date AS time,
    vnindex_close AS "VNINDEX",
    gold_sjc_sell AS "Gold SJC (VND)"
FROM marts.mart_macro_overview
WHERE _date >= $__fromTime AND _date <= $__toTime
ORDER BY _date
```

- VNINDEX on left Y-axis, Gold on right Y-axis

#### Panel 2: USD/VND Rate

```sql
SELECT
    _date AS time,
    usd_sell_rate AS "USD/VND"
FROM marts.mart_macro_overview
WHERE _date >= $__fromTime AND _date <= $__toTime
ORDER BY _date
```

#### Panel 3: Correlation Heatmap — Daily % Changes

```sql
SELECT
    _date AS time,
    vnindex_daily_pct AS "VNINDEX %",
    vn30_daily_pct AS "VN30 %",
    usd_daily_pct AS "USD %",
    gold_daily_pct AS "Gold %"
FROM marts.mart_macro_overview
WHERE _date >= $__fromTime AND _date <= $__toTime
ORDER BY _date
```

#### Panel 4: Gold-to-USD Ratio

```sql
SELECT
    _date AS time,
    gold_usd_ratio AS "Gold/USD Ratio"
FROM marts.mart_macro_overview
WHERE _date >= $__fromTime AND _date <= $__toTime
ORDER BY _date
```

---

## SUPERSET DASHBOARDS

### Connection Setup

1. Go to **Settings → Database Connections → + Database**
2. Select **ClickHouse Connect**
3. SQLAlchemy URI:
   ```
   clickhousedb://default:@clickhouse:8123/marts
   ```
4. After connecting, go to **Datasets** and add each mart table

> [!NOTE]
> Add each `mart_*` table as a separate dataset. Superset will auto-detect columns and types.

---

### Dashboard 4: Sector Treemap & Market Heatmap

Source: `mart_equity_treemap`

#### Chart 1: Sector Treemap

- Chart type: **Treemap**
- Dataset: `mart_equity_treemap`
- Filters: `_date` = latest date (use a Temporal Filter or SQL: `_date = (SELECT max(_date) FROM marts.mart_equity_treemap)`)
- Grouping: `_en_sector` → `_ticker`
- Metric (size): `SUM(turnover_proxy)`
- Color metric: `AVG(daily_return_pct)` with diverging color scheme (red ↔ green)

> [!TIP]
> This creates a treemap similar to VnDirect or Finviz's market heatmap, where the sector/stock size represents trading turnover, and color represents performance.

#### Chart 2: Top Gainers Table

- Chart type: **Table**
- Dataset: `mart_equity_treemap`
- SQL:
```sql
SELECT
    _ticker,
    _organ_name,
    _en_sector,
    _exchange,
    _close,
    daily_return_pct,
    turnover_proxy
FROM marts.mart_equity_treemap
WHERE _date = (SELECT max(_date) FROM marts.mart_equity_treemap)
ORDER BY daily_return_pct DESC
LIMIT 20
```

#### Chart 3: Top Losers Table

Same as above but `ORDER BY daily_return_pct ASC LIMIT 20`.

#### Chart 4: Sector Performance Bar Chart

- Chart type: **Bar Chart**
- Dataset: `mart_equity_treemap`
- Filters: latest date
- Dimension: `_en_sector`
- Metric: `AVG(daily_return_pct)`
- Sort: descending
- Use conditional colors (positive=green, negative=red)

---

### Dashboard 5: Fundamental Analysis

Source: `mart_fundamental_ratios`

**Superset Filters**: Add a **Filter Box** with `_ticker` and `_year`.

#### Chart 1: Profitability Margins over Time (Line chart)

```sql
SELECT
    concat(toString(_year), '-Q', toString(_quarter)) AS quarter_label,
    gross_margin_pct,
    operating_margin_pct,
    net_profit_margin_pct
FROM marts.mart_fundamental_ratios
WHERE _ticker = '{{ filter_values("_ticker", "VCB")[0] }}'
ORDER BY _year, _quarter
```

- Chart type: **Line chart** or **Mixed time series**
- X-axis: `quarter_label`
- Metrics: 3 lines for the 3 margins

#### Chart 2: ROE vs ROA (Grouped Bar)

```sql
SELECT
    concat(toString(_year), '-Q', toString(_quarter)) AS quarter_label,
    roe_pct,
    roa_pct
FROM marts.mart_fundamental_ratios
WHERE _ticker = '{{ filter_values("_ticker", "VCB")[0] }}'
ORDER BY _year, _quarter
```

#### Chart 3: Revenue & Profit Waterfall (Big Number + Trend)

- Chart type: **Big Number with Trendline**
- Metric: `SUM(_revenue)` grouped by quarter
- Use for KPI display on the dashboard header

#### Chart 4: Debt Structure (Pie chart)

```sql
SELECT
    'Short-term Debt' AS label, toFloat64(_short_debt) AS value
FROM marts.mart_fundamental_ratios
WHERE _ticker = '{{ filter_values("_ticker", "VCB")[0] }}'
ORDER BY _year DESC, _quarter DESC LIMIT 1

UNION ALL

SELECT
    'Long-term Debt', toFloat64(_long_debt)
FROM marts.mart_fundamental_ratios
WHERE _ticker = '{{ filter_values("_ticker", "VCB")[0] }}'
ORDER BY _year DESC, _quarter DESC LIMIT 1

UNION ALL

SELECT
    'Equity', toFloat64(_equity)
FROM marts.mart_fundamental_ratios
WHERE _ticker = '{{ filter_values("_ticker", "VCB")[0] }}'
ORDER BY _year DESC, _quarter DESC LIMIT 1
```

#### Chart 5: Cash Flow Breakdown (Stacked Bar)

```sql
SELECT
    concat(toString(_year), '-Q', toString(_quarter)) AS quarter_label,
    toFloat64(operating_cash_flow) AS "Operating",
    toFloat64(investing_cash_flow) AS "Investing",
    toFloat64(financing_cash_flow) AS "Financing"
FROM marts.mart_fundamental_ratios
WHERE _ticker = '{{ filter_values("_ticker", "VCB")[0] }}'
ORDER BY _year, _quarter
```

#### Chart 6: Peer Comparison Table

```sql
SELECT
    _ticker,
    _organ_name,
    _en_sector,
    roe_pct,
    roa_pct,
    gross_margin_pct,
    net_profit_margin_pct,
    debt_to_equity,
    pe_ratio_approx,
    eps_approx
FROM marts.mart_fundamental_ratios
WHERE _en_sector = (
    SELECT _en_sector FROM marts.mart_fundamental_ratios
    WHERE _ticker = 'VCB' LIMIT 1
)
AND _year = (SELECT max(_year) FROM marts.mart_fundamental_ratios)
AND _quarter = (
    SELECT max(_quarter) FROM marts.mart_fundamental_ratios
    WHERE _year = (SELECT max(_year) FROM marts.mart_fundamental_ratios)
)
ORDER BY roe_pct DESC
```

- Excellent for comparing a stock against its sector peers

---

### Dashboard 6: Gold & FX Analytics

Sources: `mart_gold_analytics`, `mart_fx_analytics`

#### Chart 1: Gold SJC Price Trend (Line chart)

```sql
SELECT
    _date,
    _buy_price,
    _sell_price,
    sell_price_ma_7,
    sell_price_ma_30
FROM marts.mart_gold_analytics
WHERE _branch = 'Hồ Chí Minh'
  AND _name = 'Vàng SJC 1L, 10L, 1KG'
ORDER BY _date
```

#### Chart 2: Gold Buy-Sell Spread (Area chart)

```sql
SELECT
    _date,
    spread_vnd AS "Spread (VND)",
    spread_margin_pct AS "Spread %"
FROM marts.mart_gold_analytics
WHERE _branch = 'Hồ Chí Minh'
  AND _name = 'Vàng SJC 1L, 10L, 1KG'
ORDER BY _date
```

#### Chart 3: USD/VND Rate + MA (Line chart)

```sql
SELECT
    _date,
    _sell AS "USD Sell Rate",
    sell_ma_7 AS "MA-7",
    sell_ma_30 AS "MA-30"
FROM marts.mart_fx_analytics
WHERE _currency_code = 'USD'
ORDER BY _date
```

#### Chart 4: Multi-Currency Comparison (Table)

```sql
SELECT
    _currency_code,
    _currency_name,
    _buy_cash,
    _buy_transfer,
    _sell,
    spread_vnd,
    sell_daily_change,
    sell_daily_change_pct
FROM marts.mart_fx_analytics
WHERE _date = (SELECT max(_date) FROM marts.mart_fx_analytics)
ORDER BY _currency_code
```

---

## Dashboard Summary Matrix

| Dashboard | Platform | Source Mart(s) | Key Charts |
|-----------|----------|---------------|------------|
| 📈 Stock Technical Analysis | **Grafana** | `mart_equity_daily_indicators` | Candlestick, SMA, BB, RSI, MACD, Volume |
| 📊 Market Index Monitor | **Grafana** | `mart_market_index_daily` | Index candlestick, multi-index comparison |
| 🌍 Macro Overview | **Grafana** | `mart_macro_overview` | Dual-axis (VNINDEX + Gold), USD/VND, correlation |
| 🗺️ Sector Treemap | **Superset** | `mart_equity_treemap` | Treemap, top gainers/losers, sector bar |
| 📋 Fundamental Analysis | **Superset** | `mart_fundamental_ratios` | Margins, ROE/ROA, cash flow, peer comparison |
| 💰 Gold & FX | **Superset** | `mart_gold_analytics`, `mart_fx_analytics` | Gold trend, spread, FX rates table |

---

## Quick Start Checklist

- [ ] **Grafana**: Add ClickHouse datasource (host=`clickhouse`, port=`8123`, database=`marts`)
- [ ] **Superset**: Add database connection (`clickhousedb://default:@clickhouse:8123/marts`)
- [ ] **Superset**: Register each `mart_*` table as a dataset
- [ ] Build Dashboard 1 (Grafana — Stock Technical) — the most impactful
- [ ] Build Dashboard 4 (Superset — Treemap) — the most visually impressive
- [ ] Build Dashboard 5 (Superset — Fundamentals) — the most analytically deep
- [ ] Build remaining dashboards as needed

> [!IMPORTANT]
> **Grafana's Candlestick panel** is native and requires no plugins. It's available in Grafana 9+.
> In the panel editor, select "Candlestick" from the visualization dropdown. Map the fields: `open`, `high`, `low`, `close`.
