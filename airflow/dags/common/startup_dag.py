import logging
from airflow.decorators import task

logger = logging.getLogger(__name__)


@task
def start_up_dag(**context):
    logger.info("Starting up DAG")
