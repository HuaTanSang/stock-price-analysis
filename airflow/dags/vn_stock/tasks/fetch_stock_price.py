import logging
from datetime import datetime

from vnstock import Market
from airflow.decorators import task

from common.utils.minio_helper import construct_minio_key, get_minio_hook
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

    try:
        market = Market()

        run_start_date = start_date or datetime.now().strftime("%Y-%m-%d")
        run_end_date = end_date or datetime.now().strftime("%Y-%m-%d")

        stock_price_data_df = market.equity(ticker_symbol).ohlcv(
            start=run_start_date, end=run_end_date, interval=interval
        )

        if stock_price_data_df is None or stock_price_data_df.empty:
            logger.warning(
                "No stock price data found for ticker=%s, date range=%s to %s",
                ticker_symbol,
                run_start_date,
                run_end_date,
            )
            return

        key = construct_minio_key(
            prefix_type=f"stock_price/interval={interval}",
            file_format="parquet",
            date=run_start_date,
        )

        data = stock_price_data_df.to_parquet()
        logger.info(f"Starting to upload data to {bucket_name}")
        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )

    except ValueError as e:
        logger.warning(
            "No valid data returned from vnstock for ticker=%s, start_date=%s, end_date=%s. Reason: %s",
            ticker_symbol,
            start_date,
            end_date,
            e,
        )

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


@task
def get_frequent_tickers_from_minio() -> list:
    """Getting frequent ticker symbol from MinIO"""
    s3_hook = get_minio_hook()

    file_content = s3_hook.read_key(
        key="frequent_ticker/tickers.txt", bucket_name="vn-stock"
    )

    tickers = [ticker.strip() for ticker in file_content.split(",") if ticker.strip()]
    return tickers
