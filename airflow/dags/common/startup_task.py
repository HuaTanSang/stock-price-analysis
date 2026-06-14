from airflow.decorators import task


@task
def startup_task():
    print("Dag is starting...")
