from vnstock import Retail

def fetch_gold_price(source: str, date: str): 
    """Fetch gold price data for a given ticker symbol and date range using vnstock API

    Args:
        None"""
    retail = Retail()
    gold_price_data = retail.gold()
    return gold_price_data