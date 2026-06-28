import pendulum
from airflow.decorators import dag


@dag(
    dag_id="vnstock_fetch_exchange_rate_pipeline",
    schedule="0 15 * * 1-5",
    start_date=pendulum.datetime(2026, 1, 1, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "exchange_rate", "daily"],
)
def vnstock_exchange_rate_dag():
    from common.startup_dag import start_up_dag
    from common.check_trading_date_task import is_trading_day
    from vn_stock.tasks.fetch_exchange_rate import fetch_and_upload_exchange_rate
    from common.end_dag import end_dag

    run_date_template = "{{ ds }}"

    start_up = start_up_dag()
    check_trading_date = is_trading_day()
    fetch_and_upload_exchange_rate = fetch_and_upload_exchange_rate(
        bucket_name="vn-stock", date=run_date_template
    )
    end = end_dag()

    start_up >> check_trading_date >> fetch_and_upload_exchange_rate >> end


vnstock_exchange_rate_dag()
