import logging
from vnstock import Reference 

logger = logging.getLogger(__name__)

def get_vn_ticker_symbol():
    """Get all ticker symbols of Vietnam stock market using vnstock API
    Args: 
    - None
    Return: List of ticker symbol in Vietnam market
    """
    try: 
        ref = Reference()
        industries = ref.equity().list() 
        return industries
    except Exception as e: 
        logger.exception(
            f"Error while fetching ticker symbol in Vietnam market"
        )
        raise RuntimeError(f"Error while fetching ticker symbol") from e 