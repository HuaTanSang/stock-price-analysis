import logging
from vnstock import Market

logger = logging.getLogger(__name__) 

def fetch_stock_price(ticker_symbol: str, start_date: str, end_date: str) -> pd.DataFrame:
    """Fetch stock price data for a given ticker symbol and date range using vnstock API

    Args:
        ticker_symbol (str): Ticker symbol of the stock
        start_date (str): Start date of the date range in 'YYYY-MM-DD' format
        end (str): End date of the date range in 'YYYY-MM-DD' format
    Returns:
        pd.DataFrame: DataFrame of OHLCV data for the given ticker symbol and date range
    """
    try:
        market = Market()
        stock_price_data = market.equity(ticker_symbol).ohlcv(start_date, end_date)
        return stock_price_data
    except Exception as e: 
        logger.exception(
            f"Error while fetching stock price from vnstock with ticker", 
            ticker_symbol, 
            start_date, 
            end_date
        )
        raise RuntimeError(
            f"Failed to fetch stock price from {ticker_symbol}, start_date={start_date}, end_date={end_date}"
        ) from e 