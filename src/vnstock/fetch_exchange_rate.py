import logging
from vnstock import Retail

logger = logging.getLogger(__name__)


def fetch_exchange_rate(date: str):
    """Fetch exchange rate from Vietcombankk for multiple currencies

    Args:
    - date (str): Date for which to fetch exchange rate data in 'YYYY-MM-DD' format
    Return:
    - schema: (str) currency
    - buy_cash: (str) buy price by cash
    - buy-transfer: (str) Buy price by banking
    - sell: sell price
    """

    logger.info("Starting to fetch exchange rate data from vnstock")

    try:
        retail = Retail()
        exchange_rate_data = retail.exchange_rate(date)
        return exchange_rate_data

    except Exception as e:
        logger.error("Error at fetch_exchange_rate module", date)
        raise RuntimeError(f"Fail to fetch exchange rate on date={date}") from e


print(fetch_exchange_rate("2026-06-16"))
