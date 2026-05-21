from vnstock import Retail

def fetch_exchange_rate(date: str): 
    """Fetch exchange rate from Vietcombankk for multiple currencies

    Args:
        date (str): Date for which to fetch exchange rate data in 'YYYY-MM-DD' format"""
    retail = Retail()
    exchange_rate_data = retail.exchange_rate(date)
    return exchange_rate_data