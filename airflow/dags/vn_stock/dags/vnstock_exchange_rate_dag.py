import pendulum
from airflow.decorators import dag


@dag(
    dag_id="vnstock_fetch_exchange_rate_pipeline",
    schedule="@daily",
    start_date=pendulum.datetime(2025, 1, 1, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "exchange_rate", "daily"],
)
def vnstock_exchange_rate_dag():
    from vn_stock.tasks.fetch_exchange_rate import fetch_and_upload_exchange_rate

    run_date_template = "{{ ds }}"

    fetch_and_upload_exchange_rate(bucket_name="vn-stock", date=run_date_template)


vnstock_exchange_rate_dag()
