import logging
from datetime import datetime

from vnstock import Market
from airflow.decorators import task

from common.utils.minio_helper import get_minio_hook
from common.save_data_to_minio import save_data_to_minio


logger = logging.getLogger(__name__)


@task
def fetch_and_upload_stock_price(
    bucket_name: str,
    ticker_symbol: str,
    start_date: str | None = None,
    end_date: str | None = None,
    interval: str = "1D",
) -> None:
    """Fetch stock price data for a given ticker symbol and date range using vnstock API.
    Args:
    - ticker_symbol (str): Ticker symbol of the stock.
    - start_date (str): Start date in 'YYYY-MM-DD' format.
    - end_date (str): End date in 'YYYY-MM-DD' format.
    - interval: (str) interval time between open and close price
    Returns:
    - None
    """

    run_start_date = start_date or datetime.now().strftime("%Y-%m-%d")
    run_end_date = end_date or datetime.now().strftime("%Y-%m-%d")

    try:
        market = Market()
        stock_price_data_df = market.equity(ticker_symbol).ohlcv(
            start=run_start_date, end=run_end_date, interval=interval
        )
    except ValueError as e:
        logger.warning(
            "No trading data available (market may be closed) for "
            "ticker=%s, date range=%s to %s. Reason: %s",
            ticker_symbol,
            run_start_date,
            run_end_date,
            e,
        )
        return
    except ConnectionError as e:
        logger.error(
            "Network error while fetching stock price for "
            "ticker=%s, date range=%s to %s. Reason: %s",
            ticker_symbol,
            run_start_date,
            run_end_date,
            e,
        )
        raise RuntimeError(
            f"Network error fetching stock price for {ticker_symbol}, "
            f"start_date={run_start_date}, end_date={run_end_date}"
        ) from e
    except Exception as e:
        logger.exception(
            "Unexpected error while fetching stock price from vnstock for "
            "ticker=%s, date range=%s to %s",
            ticker_symbol,
            run_start_date,
            run_end_date,
        )
        raise RuntimeError(
            f"Failed to fetch stock price for {ticker_symbol}, "
            f"start_date={run_start_date}, end_date={run_end_date}"
        ) from e

    if stock_price_data_df is None or stock_price_data_df.empty:
        logger.warning(
            "No stock price data returned for ticker=%s, date range=%s to %s. "
            "The market may have been closed on this date.",
            ticker_symbol,
            run_start_date,
            run_end_date,
        )
        return

    stock_price_data_df["ticker"] = ticker_symbol
    stock_price_data_df["interval"] = interval

    date_str = run_start_date
    year, month, day = date_str.split("-")
    key = (
        f"stock_price/ticker={ticker_symbol}/interval={interval}"
        f"/{year}/{month}/{day}"
        f"/stock_price-{ticker_symbol}-{interval}-{date_str}.parquet"
    )

    try:
        data = stock_price_data_df.to_parquet()
        logger.info(
            "Uploading stock price data to %s/%s (ticker=%s, interval=%s)",
            bucket_name,
            key,
            ticker_symbol,
            interval,
        )
        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )
        logger.info("Upload complete: %s/%s", bucket_name, key)
    except Exception as e:
        logger.exception(
            "Failed to upload stock price to MinIO for " "ticker=%s, date=%s, key=%s",
            ticker_symbol,
            run_start_date,
            key,
        )
        raise RuntimeError(
            f"Failed to upload stock price to MinIO. "
            f"ticker={ticker_symbol}, key={key}"
        ) from e


@task
def get_frequent_tickers_from_minio() -> list:
    """Getting frequent ticker symbol from MinIO"""
    s3_hook = get_minio_hook()

    file_content = s3_hook.read_key(
        key="frequent_ticker/tickers.txt", bucket_name="vn-stock"
    )

    tickers = [ticker.strip() for ticker in file_content.split(",") if ticker.strip()]
    return tickers
