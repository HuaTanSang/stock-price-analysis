import logging 
import pandas as pd 

from vnstock import Retail
from airflow.decorators import task 

logger = logging.getLogger(__name__)

@task
def fetch_exchange_rate(date: str) -> pd.DataFrame: 
    """Fetch exchange rate from Vietcombankk for multiple currencies

    Args:
    - date (str): Date for which to fetch exchange rate data in 'YYYY-MM-DD' format
    Returns: 
    - schema: (str) currency
    - buy_cash: (str) buy price by cash
    - buy_transfer: (str) buy price by banking
    - sell: sell price  
    """
        
    logger.info("Starting to fetch exchange rate data from vnstock")
    
    try:
        retail = Retail()
        exchange_rate_data = retail.exchange_rate(date)
        return exchange_rate_data

    except Exception as e: 
        logger.exception(
            "Error at fetch_exchange_rate module date=%s", 
            date
        )
        raise RuntimeError(f"Fail to fetch exchange rate on date={date}") from e
