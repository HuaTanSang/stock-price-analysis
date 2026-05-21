from vnstock import Market

def fetch_stock_price(ticker_symbol: str, start_date: str, end: str):
    """Fetch stock price data for a given ticker symbol and date range using vnstock API

    Args:
        ticker_symbol (str): Ticker symbol of the stock
        start_date (str): Start date of the date range in 'YYYY-MM-DD' format
        end (str): End date of the date range in 'YYYY-MM-DD' format
    Returns:
        pd.DataFrame: DataFrame of OHLCV data for the given ticker symbol and date range
    """
    
    market = Market()
    stock_price_data = market.equity(ticker_symbol).ohlcv(start_date, end)
    return stock_price_data