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
    logger.info("[START] Starting to get and upload ticker symbol of Vietnam market from vnstock...") 
    
    try: 
        ref = Reference()
        ticker_symbols_df = ref.equity().list() 

        data = ticker_symbols_df.to_csv(index=False)
        data_bytes = data.encode('utf-8')
        
        key = construct_minio_key(prefix_type="vn_ticker_symbol", file_format="csv")
        logger.info(f"Starting to upload data to {bucket_name}")
        
        save_data_to_minio(data=data_bytes, bucket_name=bucket_name, key=key, file_format="csv")
        
        logger.info(f"Uploaded successfully at {bucket_name}/{key}")
        
        return {
            "bucket_name": bucket_name, 
            "key": key,
            "status": "success"
        }
        
    except Exception as e: 
        logger.exception(
            f"Error while fetching ticker symbol in Vietnam market"
        )
        raise RuntimeError(f"Error while fetching ticker symbol") from e 