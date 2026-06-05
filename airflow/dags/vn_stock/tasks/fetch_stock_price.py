import logging

from common.utils.minio_helper import construct_minio_key
from common.save_data_to_minio import save_data_to_minio

from airflow.decorators import task
from vnstock import Market




logger = logging.getLogger(__name__) 

@task 
def fetch_stock_price_and_save_to_minio(bucket_name: str, ticker_symbol: str, start_date: str, end_date: str) -> None:
    """Fetch stock price data for a given ticker symbol and date range using vnstock API

    Args:
    - ticker_symbol (str): Ticker symbol of the stock
    - start_date (str): fetching date start in format YYYY-MM-DD
    - end_date: (str) fetching date end in format YYYY-MM-DD
    Returns:
    - None
    """
    logger.info(f"[START] Starting to get and upload OHLCV data of {ticker_symbol} between {start_date} and {end_date}...") 
    
    try:
        market = Market()
        stock_price_data = market.equity(ticker_symbol).ohlcv(start_date, end_date)
        
        data = ticker_symbol.to_csv(index=False) 
        data_bytes = data.encode('utf-8') 
        
        key = construct_minio_key(prefix_type="ohlcv", file_format="csv")
        logger.info(f"Starting to upload data to {bucket_name}")
        
        save_data_to_minio(data=data_bytes, bucket_name=bucket_name, key=key, file_format="csv")
        
        logger.info(f"Uploaded successfully at {bucket_name}/{key}")
        
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