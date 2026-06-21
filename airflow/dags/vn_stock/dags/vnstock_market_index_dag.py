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
    from vn_stock.tasks.fetch_market_index import fetch_and_upload_market_index

    index_symbols = ["VNINDEX", "VN30", "HNXINDEX"]

    for index_symbol in index_symbols:
        fetch_and_upload_market_index(
            bucket_name="vn-stock",
            index_symbol=index_symbol,
            start_date="{{ ds }}",
            end_date="{{ ds }}",
            interval="1D",
        )


vnstock_market_index_dag()
