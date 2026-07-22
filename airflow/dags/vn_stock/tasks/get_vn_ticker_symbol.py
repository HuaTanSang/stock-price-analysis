import logging

from common.utils.minio_helper import construct_minio_key
from common.save_data_to_minio import save_data_to_minio

from vnstock import Reference
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
        ref = Reference()

        # List equity
        ticker_symbols_df = ref.equity().list()
        data = ticker_symbols_df.to_parquet()
        key = construct_minio_key(prefix_type="vn_ticker_symbol", file_format="parquet")
        logger.info(f"Starting to upload data to {bucket_name}")
        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )
        logger.info(f"Uploaded successfully at {bucket_name}/{key}")

        # List equity by industry
        ticker_symbol_by_industry_df = ref.equity().list_by_industry()
        data = ticker_symbol_by_industry_df.to_parquet()
        key = construct_minio_key(
            prefix_type="vn_ticker_symbol_by_industry", file_format="parquet"
        )
        logger.info(f"Starting to upload data to {bucket_name}")
        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )
        logger.info(f"Uploaded successfully at {bucket_name}/{key}")

        # List equity by exchange
        ticker_symbol_by_exchange_df = ref.equity().list_by_exchange()
        data = ticker_symbol_by_exchange_df.to_parquet()
        key = construct_minio_key(
            prefix_type="vn_ticker_symbol_by_exchange", file_format="parquet"
        )
        logger.info(f"Starting to upload data to {bucket_name}")
        save_data_to_minio(
            data=data, bucket_name=bucket_name, key=key, file_format="parquet"
        )
        logger.info(f"Uploaded successfully at {bucket_name}/{key}")

    except Exception as e:
        logger.exception("Error while fetching ticker symbol in Vietnam market")
        raise RuntimeError("Error while fetching ticker symbol") from e
