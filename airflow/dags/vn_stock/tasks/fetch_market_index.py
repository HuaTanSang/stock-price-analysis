import logging
from datetime import datetime

from vnstock import Market
from airflow.decorators import task


from common.save_data_to_minio import save_data_to_minio


logger = logging.getLogger(__name__)


@task
def fetch_and_upload_market_index(
    bucket_name: str,
    index_symbol: str,
    start_date: str | None = None,
    end_date: str | None = None,
    interval: str = "1D",
) -> None:
    """Fetch market index OHLCV data (e.g. VNINDEX, VN30) using vnstock API.

    Args:
        bucket_name (str): MinIO bucket name.
        index_symbol (str): Market index symbol (e.g. 'VNINDEX', 'VN30', 'HNXINDEX').
        start_date (str | None): Start date in 'YYYY-MM-DD' format.
        end_date (str | None): End date in 'YYYY-MM-DD' format.
        interval (str): Time interval (default '1D').

    Returns:
        None
    """

    run_start_date = start_date or datetime.now().strftime("%Y-%m-%d")
    run_end_date = end_date or datetime.now().strftime("%Y-%m-%d")

    try:
        market = Market()
        index_data_df = market.index(index_symbol).ohlcv(
            start=run_start_date, end=run_end_date, interval=interval
        )
    except ValueError as e:
        logger.warning(
            "No trading data available (market may be closed) for "
            "index=%s, date range=%s to %s. Reason: %s",
            index_symbol,
            run_start_date,
            run_end_date,
            e,
        )
        return
    except ConnectionError as e:
        logger.error(
            "Network error while fetching market index for "
            "index=%s, date range=%s to %s. Reason: %s",
            index_symbol,
            run_start_date,
            run_end_date,
            e,
        )
        raise RuntimeError(
            f"Network error fetching market index for {index_symbol}, "
            f"start_date={run_start_date}, end_date={run_end_date}"
        ) from e
    except Exception as e:
        logger.exception(
            "Unexpected error while fetching market index from vnstock for "
            "index=%s, date range=%s to %s",
            index_symbol,
            run_start_date,
            run_end_date,
        )
        raise RuntimeError(
            f"Failed to fetch market index for {index_symbol}, "
            f"start_date={run_start_date}, end_date={run_end_date}"
        ) from e

    if index_data_df is None or index_data_df.empty:
        logger.warning(
            "No market index data returned for index=%s, date range=%s to %s. "
            "The market may have been closed on this date.",
            index_symbol,
            run_start_date,
            run_end_date,
        )
        return

    index_data_df["index_symbol"] = index_symbol

    date_str = run_start_date
    year, month, day = date_str.split("-")
    key = (
        f"market_index/index={index_symbol}"
        f"/{year}/{month}/{day}"
        f"/market_index-{index_symbol}-{date_str}.parquet"
    )

    try:
        data = index_data_df.to_parquet()
        logger.info(
            "Uploading market index data to %s/%s (index=%s)",
            bucket_name,
            key,
            index_symbol,
        )
        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )
        logger.info("Upload complete: %s/%s", bucket_name, key)
    except Exception as e:
        logger.exception(
            "Failed to upload market index to MinIO for " "index=%s, date=%s, key=%s",
            index_symbol,
            run_start_date,
            key,
        )
        raise RuntimeError(
            f"Failed to upload market index to MinIO. "
            f"index={index_symbol}, key={key}"
        ) from e
