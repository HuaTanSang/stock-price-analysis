import logging

from common.utils.minio_helper import construct_minio_key
from common.save_data_to_minio import save_data_to_minio

from vnstock import Listing
import pandas as pd
from airflow.decorators import task

logger = logging.getLogger(__name__)


@task
def get_vn_ticker_symbol_and_save_to_minio(bucket_name: str) -> None:
    """Get all ticker symbols of Vietnam stock market using vnstock API
    Args:
    - None
    Return: List of ticker symbol in Vietnam market
    """
    logger.info(
        "[START] Starting to get and upload ticker symbol of Vietnam market from vnstock..."
    )

    try:
        # Use KBS listing to fetch enriched metadata (exchange, industry, sector)
        listing = Listing(source="kbs")

        # 1. Fetch by exchange to get 'exchange' and 'type' (sector)
        hose_df = listing.symbols_by_exchange("HOSE")
        hnx_df = listing.symbols_by_exchange("HNX")
        upcom_df = listing.symbols_by_exchange("UPCOM")
        exchanges_df = pd.concat([hose_df, hnx_df, upcom_df])

        # 2. Fetch industries
        industries_df = listing.symbols_by_industries()

        # 3. Merge them
        ticker_symbols_df = exchanges_df.merge(industries_df, on="symbol", how="left")

        # 4. Rename columns to match raw_vnstock_ticker_symbols schema expectation
        ticker_symbols_df = ticker_symbols_df.rename(
            columns={"symbol": "ticker", "type": "sector"}
        )

        data = ticker_symbols_df.to_parquet()

        key = construct_minio_key(prefix_type="vn_ticker_symbol", file_format="parquet")
        logger.info(f"Starting to upload data to {bucket_name}")

        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )

        logger.info(f"Uploaded successfully at {bucket_name}/{key}")

        return {"bucket_name": bucket_name, "key": key, "status": "success"}

    except Exception as e:
        logger.exception("Error while fetching ticker symbol in Vietnam market")
        raise RuntimeError("Error while fetching ticker symbol") from e
