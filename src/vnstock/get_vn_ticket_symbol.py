from vnstock import Reference 


def get_vn_ticker_symbol():
    """Get all ticker symbols of Vietnam stock market using vnstock API"""
    ref = Reference()
    industries = ref.equity().list() 
    return industries