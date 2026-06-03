import logging 
from datetime import datetime 

from common.utils.minio_helper import construct_minio_key
from common.save_data_to_minio import save_data_to_minio

from vnstock import Retail
from airflow.decorators import task 

logger = logging.getLogger(__name__)

@task
def fetch_and_upload_exchange_rate(bucket_name: str, date: str) -> None: 
    """Fetch exchange rate from Vietcombank for multiple currencies

    Args:
    - date (str): Date for which to fetch exchange rate data in 'YYYY-MM-DD' format
    Returns: 
    - schema: (str) currency
    - buy_cash: (str) buy price by cash
    - buy_transfer: (str) buy price by banking
    - sell: sell price  
    """
        
    logger.info("[START] Starting to fetch exchange rate data from vnstock...")
    
    try:
        retail = Retail()
        exchange_rate_df = retail.exchange_rate(date)

        logger.info(f"Fetching exchange rate successfully!")

        data = exchange_rate_df.to_csv(index=False)
        data_bytes = data.encode('utf-8')
        
        date = date or datetime.now().strftime("%Y-%m-%d")
        key = construct_minio_key(prefix_type="exchange_rate", date=date, file_format="csv")

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
            "Error at fetch_exchange_rate module date=%s", 
            date
        )
        raise RuntimeError(f"Fail to fetch exchange rate on date={date}") from e
