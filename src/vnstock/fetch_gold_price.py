import logging
from vnstock import Retail

logger = logging.getLogger(__name__)


def fetch_gold_price(source: str | None = None, date: str | None = None):
    """
    Fetch gold price data using vnstock API.

    Args:
        source (str | None): Data source. Default is SJC. Can be "btmc".
        date (str | None): Date in YYYY-MM-DD format. Default is current date.

    Returns:
        Gold price data returned by vnstock, including:
        - time: updated time
        - buy: buy price
        - sell: sell price
        - type: type of gold

    Raises:
        RuntimeError: If fetching gold price data fails.
    """
    try:
        retail = Retail()
        gold_price_data = retail.gold(source, date)
        return gold_price_data

    except Exception as e:
        logger.exception(
            "Error while fetching gold price from vnstock. source=%s, date=%s",
            source,
            date,
        )
        raise RuntimeError(
            f"Error while fetching gold price from vnstock. source={source}, date={date}"
        ) from e


print(fetch_gold_price("SJC", "2026-06-15"))
