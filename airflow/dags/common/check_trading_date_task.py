from airflow.decorators import task
from datetime import datetime
from constant import VIETNAM_HOLIDAYS
import logging

logger = logging.getLogger(__name__)


@task.short_circuit
def is_trading_day(**context):
    ds = context["ds"]
    if ds:
        execution_date = datetime.strptime(ds, "%Y-%m-%d")
    else:
        execution_date = context["execution_date"]

    if execution_date.weekday() >= 5:
        logger.info(f"Market is closed on {ds}. Skipping downstream tasks.")
        return False

    if execution_date in VIETNAM_HOLIDAYS:
        logger.info(f"Market is closed on {ds}. Skipping downstream tasks.")
        return False

    logger.info(f"Market is open on {ds}. Proceeding with DAG.")
    return True
