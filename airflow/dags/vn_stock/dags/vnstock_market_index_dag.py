import pendulum
from airflow.decorators import dag


@dag(
    dag_id="vnstock_fetch_market_index_pipeline_daily",
    schedule="@daily",
    start_date=pendulum.datetime(2025, 1, 6, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "market_index", "daily"],
)
def vnstock_market_index_dag():
    from common.startup_dag import start_up_dag
    from common.end_dag import end_dag
    from common.check_trading_date_task import is_trading_day
    from vn_stock.tasks.fetch_market_index import fetch_and_upload_market_index

    index_symbols = ["VNINDEX", "VN30", "HNXINDEX"]
    run_date_template = "{{ ds }}"

    start_up = start_up_dag()
    check_trading_date = is_trading_day()

    fetch_and_upload_market_index_task = fetch_and_upload_market_index.partial(
        bucket_name="vn-stock",
        start_date=run_date_template,
        end_date=run_date_template,
        interval="1D",
    ).expand(index_symbol=index_symbols)

    end = end_dag()

    start_up >> check_trading_date >> fetch_and_upload_market_index_task >> end


vnstock_market_index_dag()
