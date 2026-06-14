from airflow.decorators import task
from airflow.utils.trigger_rule import TriggerRule


@task(trigger_rule=TriggerRule.ALL_DONE)
def end_task():
    print("Dag end")
