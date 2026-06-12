import logging

import pandas as pd
from vnstock import Market

logger = logging.getLogger(__name__)


def fetch_stock_price(
    ticker_symbol: str, start_date: str, end_date: str, interval: str = "1D"
) -> pd.DataFrame:
    """Fetch stock price data for a given ticker symbol and date range using vnstock API.

    Args:
        ticker_symbol (str): Ticker symbol of the stock.
        start_date (str): Start date in 'YYYY-MM-DD' format.
        end_date (str): End date in 'YYYY-MM-DD' format.
        interval: (str) interval time between open and close price
    Returns:
        pd.DataFrame: OHLCV data for the given ticker symbol and date range.
    """
    try:
        market = Market()
        stock_price_data = market.equity(ticker_symbol=ticker_symbol).ohlcv(
            start_date=start_date, end_date=end_date, interval=interval
        )

        if stock_price_data is None or stock_price_data.empty:
            logger.warning(
                "No stock price data found for ticker=%s, start_date=%s, end_date=%s",
                ticker_symbol,
                start_date,
                end_date,
            )
            return pd.DataFrame()

        return stock_price_data

    except ValueError as e:
        logger.warning(
            "No valid data returned from vnstock for ticker=%s, start_date=%s, end_date=%s. Reason: %s",
            ticker_symbol,
            start_date,
            end_date,
            e,
        )
        return pd.DataFrame()

    except Exception as e:
        logger.exception(
            "Unexpected error while fetching stock price from vnstock with ticker=%s, start_date=%s, end_date=%s",
            ticker_symbol,
            start_date,
            end_date,
        )
        raise RuntimeError(
            f"Failed to fetch stock price from {ticker_symbol}, "
            f"start_date={start_date}, end_date={end_date}"
        ) from e
