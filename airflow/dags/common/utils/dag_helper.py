from datetime import datetime

from common.constant import VIETNAM_HOLIDAYS


def is_market_closed(date: str, holiday_list: list = VIETNAM_HOLIDAYS) -> bool:
    """Check if input date is weekend or holiday. This behovior is needed because on these days, the market is closed

    Args:
        date (str): input date of the dag, in the format YYYY-MM-DD
        holiday_list (list): list of holiday of specific market
    Returns:
        bool: does the market closed or not
    """
    if date in holiday_list:
        return True

    try:
        dt = datetime.strptime(date, "%Y-%m-%d")
        # 5 is Saturday, 6 is Sunday
        if dt.weekday() >= 5:
            return True
    except ValueError:
        pass

    return False
