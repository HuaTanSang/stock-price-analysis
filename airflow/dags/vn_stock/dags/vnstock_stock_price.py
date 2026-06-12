import pendulum
from airflow.decorators import dag


@dag(
    dag_id="vnstock_fetch_stock_price_pipeline_daily",
    schedule="@daily",
    start_date=pendulum.datetime(2025, 1, 6, tz="Asia/Ho_Chi_Minh"),
    catchup=False,
    tags=["vnstock", "stock_price", "daily"],
)
def vnstock_stock_price_dags():
    from vn_stock.tasks.fetch_stock_price import (
        fetch_and_upload_stock_price,
        get_frequent_tickers_from_minio,
    )

    ticker_list = get_frequent_tickers_from_minio()

    fetch_and_upload_stock_price.partial(
        bucket_name="vn-stock",
        start_date="{{ ds }}",
        end_date="{{ ds }}",
        interval="1D",
    ).expand(ticker_symbol=ticker_list)


vnstock_stock_price_dags()
