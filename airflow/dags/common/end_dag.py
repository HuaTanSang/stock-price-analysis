import logging
from airflow.decorators import task
from airflow.utils.trigger_rule import TriggerRule

logger = logging.getLogger(__name__)


@task(trigger_rule=TriggerRule.ALL_DONE)
def end_dag():
    logger.info("Dag end")
