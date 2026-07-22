import pendulum
from airflow.decorators import dag


@dag(
    dag_id="vnstock_get_vn_ticker_symbol",
    schedule=None,
    start_date=pendulum.datetime(2025, 1, 1, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "ticker_symbol", "once"],
)
def vnstock_get_ticker_symbols_in_vietnam_dag():
    from common.startup_dag import start_up_dag
    from vn_stock.tasks.get_vn_ticker_symbol import (
        get_vn_ticker_symbol_and_save_to_minio,
    )
    from common.end_dag import end_dag

    start_up = start_up_dag()
    get_vn_ticker_symbol_and_save_to_minio_task = (
        get_vn_ticker_symbol_and_save_to_minio(bucket_name="vn-stock")
    )
    end = end_dag()

    start_up >> get_vn_ticker_symbol_and_save_to_minio_task >> end


vnstock_get_ticker_symbols_in_vietnam_dag()
