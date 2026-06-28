import logging

from vnstock import Reference

logger = logging.getLogger(__name__)


def get_vn_ticker_symbol_and_save_to_minio(bucket_name: str) -> None:
    """Get all ticker symbols of Vietnam stock market using vnstock API
    Args:
    - None
    Return: List of ticker symbol in Vietnam market
    """
    logger.info(
        "[START] Starting to get and upload ticker symbol of Vietnam market from vnstock..."
    )

    ref = Reference()
    ticker_symbols_df = ref.equity().list()

    print(ticker_symbols_df)


get_vn_ticker_symbol_and_save_to_minio("something")
